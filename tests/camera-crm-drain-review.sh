#!/usr/bin/env bash
# COPR only: actual transport body and retained callback model, no target I/O.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
manifest=$project/manifests/camera-crm-drain-review-20261105.json
(cd "$project"; jq -r '.inputs[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
mkdir -p "$work/original/src/camera/provider" "$work/fixed/src/camera/provider"
for tree in original fixed; do
    install -m644 "$project/src/camera/provider/camcc-sm7675-crm-transport.h" \
        "$work/$tree/src/camera/provider/camcc-sm7675-crm-transport.h"
done
(cd "$work/fixed"; patch -p1 --fuzz=0 --batch -i "$project/patches/camera/0002-crm-post-drain-validation.patch")
printf '%s  %s\n' "$(jq -er .proposed_header_sha256 "$manifest")" \
    "$work/fixed/src/camera/provider/camcc-sm7675-crm-transport.h" | sha256sum -c --strict -
sed '/^#include </d' "$project/src/camera/provider/camcc-sm7675-crm-core.h" > "$work/camcc-sm7675-crm-core.h"
sed 's/^int main(void)$/static void retained_contract(void)/' \
    "$project/tests/fixtures/camera-crm-transport-check.c" > "$work/retained-fixture.c"
[[ $(grep -c '^static void retained_contract(void)$' "$work/retained-fixture.c") == 1 ]]
cp "$project/tests/fixtures/camera-crm-drain-review.c" "$work/review.c"
cat > "$work/crm-transport.h" <<'SHIM'
static void checking_synchronize_irq(unsigned irq);
#define synchronize_irq checking_synchronize_irq
#include "production-transport.h"
#undef synchronize_irq
SHIM
ulimit -c 0
for compiler in gcc clang; do
    for mode in ordinary sanitized; do
        flags=(-O2)
        if [[ $mode == sanitized ]]; then
            flags=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
        fi
        for tree in original fixed; do
            sed '/^#include </d' "$work/$tree/src/camera/provider/camcc-sm7675-crm-transport.h" > "$work/production-transport.h"
            "$compiler" -std=gnu11 -UNDEBUG -Wall -Wextra -Werror "${flags[@]}" \
                -I"$work" "$work/review.c" -o "$work/review"
            if [[ $tree == fixed ]]; then
                "$work/review"
            else
                status=0
                ("$work/review" > "$work/negative.log" 2>&1) 2>/dev/null || status=$?
                [[ $status == 134 ]]
                grep -Fq 'result == -EUCLEAN' "$work/negative.log"
                printf 'Exact aacc2b9 post-drain omission reproduced at required assertion: %s/%s\n' "$compiler" "$mode"
            fi
        done
    done
done
