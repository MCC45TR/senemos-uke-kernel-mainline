#!/usr/bin/env bash
# COPR worker only: actual inherited spec checks and refusal/repeat control flow.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
original=$(realpath "${1:?Original production spec}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
helper=$owner/packaging/native/overlay-governor-spec731.sh
audio_calls()
{
    awk '/^%check$/ {inside=1;next} /^%[a-z]/ {inside=0}
      inside && /bash native-profile\/tests\/(audio-|microphone-gain-contract|kernel-audio-policy-contract)/ {print}' "$1"
}
cp "$original" "$stage/exact.spec"
bash "$helper" "$stage/exact.spec"
cmp "$original" "$stage/exact.spec.before-governor-options.txt"
audio_calls "$original" > "$stage/original.audio"
audio_calls "$stage/exact.spec" > "$stage/extended.audio"
[[ $(wc -l < "$stage/original.audio") == 24 ]]
cmp "$stage/original.audio" "$stage/extended.audio"
[[ $(grep -c '^bash native-profile/tests/governor-config-contract.sh native-generated/nfc-cdsp-before-reference/.config native-generated/nfc-cdsp-reference/.config$' "$stage/exact.spec") == 2 ]]
[[ $(grep -c '^bash native-profile/tests/cdsp-pogo-config-contract.sh native-generated/nfc-cdsp-before-reference/.config$' "$stage/exact.spec") == 2 ]]
sha256sum "$stage/exact.spec" "$stage/exact.spec.before-governor-options.txt" > "$stage/exact.sha"
bash "$helper" "$stage/exact.spec"
sha256sum -c --strict --quiet "$stage/exact.sha"
printf '%s\n' 'PASS: exact spec repeat; all 24 final audio calls retained; old CDSP gate plus exact four-option delta in build and final check'
for kind in missing_loop occupied_history dangling_history hardlink missing_gate repeated_change; do
    mkdir "$stage/$kind"
    spec=$stage/$kind/kernel.spec
    cp "$original" "$spec"
    case "$kind" in
        missing_loop) sed -i 's/^for role in cdsp waydroid; do$/for role in waydroid; do/' "$spec";;
        occupied_history) printf 'occupied\n' > "$spec.before-governor-options.txt";;
        dangling_history) ln -s missing "$spec.before-governor-options.txt";;
        hardlink) ln "$spec" "$stage/$kind/other.spec";;
        missing_gate) sed -i '0,/^bash native-profile\/tests\/cdsp-pogo-config-contract.sh /{/^bash native-profile\/tests\/cdsp-pogo-config-contract.sh /d;}' "$spec";;
        repeated_change) bash "$helper" "$spec" > /dev/null; printf '\n' >> "$spec";;
    esac
    (cd "$stage/$kind"; find . -type f -print0 | sort -z | xargs -0 sha256sum; find . -printf '%y %m %p %l\n' | sort) > "$stage/before"
    if bash "$helper" "$spec" > "$stage/refusal.log" 2>&1; then printf 'Unexpected spec acceptance: %s\n' "$kind" >&2; exit 1; fi
    (cd "$stage/$kind"; find . -type f -print0 | sort -z | xargs -0 sha256sum; find . -printf '%y %m %p %l\n' | sort) > "$stage/after"
    cmp "$stage/before" "$stage/after"
    printf 'PASS: spec refusal without mutation: %s\n' "$kind"
done
