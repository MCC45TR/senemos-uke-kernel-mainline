#!/usr/bin/env bash
# COPR/source only: reject changed preimages/gates; repeat without mutation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(realpath "${1:?Owner}")
profile=$(realpath "${2:?Native profile}")
boot=$(realpath "${3:?Boot recipe}")
helper=$owner/packaging/native/overlay-camcc-bootstrap731.sh
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
seal() { (cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS); }
refuse()
{
    (cd "$profile"; find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/profile.before"
    (cd "$boot"; find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/boot.before"
    if bash "$helper" "$profile" "$boot" > "$work/refusal" 2>&1; then
        printf 'Required CAMCC layer refusal was missed\n' >&2; exit 1
    fi
    (cd "$profile"; sha256sum -c --strict --quiet "$work/profile.before")
    (cd "$boot"; sha256sum -c --strict --quiet "$work/boot.before")
}
path=src/camera/camcc-sm7675-data.h
cp "$profile/$path" "$work/old-data"
cp "$profile/source-composition.json" "$work/composition"
cp "$profile/SHA256SUMS" "$work/sums"
printf '\n/* Synthetic unreviewed preimage. */\n' >> "$profile/$path"
seal
refuse
install -m644 "$work/old-data" "$profile/$path"
install -m644 "$work/sums" "$profile/SHA256SUMS"
jq '.camera_capture_graph_activation=true' "$work/composition" > "$profile/source-composition.json"
seal
refuse
install -m644 "$work/composition" "$profile/source-composition.json"
install -m644 "$work/sums" "$profile/SHA256SUMS"
bash "$helper" "$profile" "$boot"
sha256sum "$profile/SHA256SUMS" "$boot/lock.json" > "$work/applied"
bash "$helper" "$profile" "$boot"
sha256sum -c --strict --quiet "$work/applied"
cp "$profile/$path" "$work/new-data"
cp "$profile/source-composition.json" "$work/new-composition"
cp "$profile/SHA256SUMS" "$work/new-sums"
printf '\n/* Synthetic applied-byte mutation. */\n' >> "$profile/$path"
seal
refuse
install -m644 "$work/new-data" "$profile/$path"
install -m644 "$work/new-sums" "$profile/SHA256SUMS"
jq '.camcc_bootstrap_physical_acceptance=true' "$work/new-composition" > "$profile/source-composition.json"
seal
refuse
install -m644 "$work/new-composition" "$profile/source-composition.json"
install -m644 "$work/new-sums" "$profile/SHA256SUMS"
sha256sum -c --strict --quiet "$work/applied"
printf 'CAMCC layer: four required refusals, exact repeat, retained order and admission passed\n'
