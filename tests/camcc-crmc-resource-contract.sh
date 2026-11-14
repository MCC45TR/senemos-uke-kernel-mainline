#!/usr/bin/bash
# COPR only: run the actual passive resource callbacks, never target hardware.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf ]]
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
sed '/^#include /d' "$project/src/camera/provider/camcc-sm7675-crmc-resource.h" > "$work/crmc-resource.h"
read -ra flags <<< "${CAMCC_RESOURCE_TEST_FLAGS:-}"
"${CC:-clang}" -std=gnu11 -O1 -g -Wall -Wextra -Werror "${flags[@]}" -I"$work" \
 "$project/tests/fixtures/camcc-crmc-resource-check.c" -o "$work/check"
"$work/check"
