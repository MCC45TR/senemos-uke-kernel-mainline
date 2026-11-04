#!/usr/bin/env bash
# COPR only: exercise the actual integrated callbacks and retain the old failure.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Pass prepared cumulative kernel}")
profile=$kernel/native-profile
panel=$profile/src/display/panel-xiaomi-o82.c
fixture=$profile/tests/o82-panel-contract.sh
header=$profile/src/display/o82-data.h
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
jq -e '.qualified_touch_layer==1 and .camcc_probe_observation_abi==1 and
 .ssc_observation_abi==1 and .touch_order_check==11260818' "$profile/source-composition.json" >/dev/null
cmp "$panel" "$kernel/drivers/gpu/drm/panel/panel-xiaomi-o82.c"
cmp "$profile/src/input/nt36532-uke-protocol.c" \
    "$kernel/drivers/input/touchscreen/nt36532-uke/nt36532-uke-protocol.c"
mkdir -p "$work/old/src/display"
cp "$panel" "$work/old/src/display/panel-xiaomi-o82.c"
patch --batch --fuzz=0 -R -d "$work/old" -p1 \
    -i "$profile/patches/display/0074-o82-touch-retain-before-off.patch"
printf '%s  %s\n' 6b43d63765b157fad76c48ee9de7aa68e2a8ab88c7fec0c271526e6d0a39d0d4 \
    "$work/old/src/display/panel-xiaomi-o82.c" | sha256sum -c --strict -
set +e
CC=gcc bash "$fixture" "$work/old/src/display/panel-xiaomi-o82.c" "$header" "$kernel" > "$work/old.log" 2>&1
status=$?
set -e
if [[ $status != 134 ]] || ! grep -Fq 'Touch retention must precede panel OFF commands' "$work/old.log"; then
    cat "$work/old.log"
    printf 'Original panel missed the required independent assertion134\n' >&2
    exit 1
fi
printf 'Original cumulative panel reproduces the independent early-blank failure134\n'
cat > "$work/asan-cc" <<'CC'
#!/usr/bin/env bash
set -Eeuo pipefail
exec "${UKE_PANEL_CC:?Pass native compiler}" -fsanitize=address -fno-omit-frame-pointer "$@"
CC
chmod 700 "$work/asan-cc"
export ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:detect_leaks=1
export UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1
for compiler in gcc clang; do
    CC=$compiler bash "$fixture" "$panel" "$header" "$kernel"
    UKE_PANEL_CC=$compiler CC=$work/asan-cc bash "$fixture" "$panel" "$header" "$kernel"
done
bash "$profile/tests/touch-gesture-ack-regression.sh"
for compiler in gcc clang; do
    CC=$compiler UKE_TOUCH_SANITIZE= bash "$profile/tests/touch-protocol-contract.sh"
    CC=$compiler UKE_TOUCH_SANITIZE=1 bash "$profile/tests/touch-protocol-contract.sh"
done
printf 'Integrated actual panel/protocol callbacks pass; full kernel, DNF and physical acceptance remain separate\n'
