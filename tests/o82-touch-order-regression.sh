#!/usr/bin/env bash
# COPR only: execute the retained panel's callbacks with an early-blank contract.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Pass the prepared qualified11003 kernel}")
addon=$(cd -- "$(dirname -- "$0")/.." && pwd)
profile=$kernel/native-profile
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
ulimit -c 0
[[ $(jq -er .source_commit "$profile/source-composition.json") == 261d85e218906f78d37810db78a4aa80cd900067 ]]
panel=$profile/src/display/panel-xiaomi-o82.c
fixture=$profile/tests/o82-panel-contract.sh
header=$profile/src/display/o82-data.h
cmp "$panel" "$kernel/drivers/gpu/drm/panel/panel-xiaomi-o82.c"
printf 'Qualified11003 original panel and fixture SHA256:\n'
sha256sum "$panel" "$fixture"
CC=gcc bash "$fixture" "$panel" "$header" "$kernel"

# Extend the actual inherited callback fixture; do not replace its other checks.
patch -d "$profile" -p1 --fuzz=0 --dry-run -i "$addon/patches/display/0074-o82-touch-retain-test.patch"
patch -d "$profile" -p1 --fuzz=0 -i "$addon/patches/display/0074-o82-touch-retain-test.patch"
set +e
CC=gcc bash "$fixture" "$panel" "$header" "$kernel" > "$stage/before.log" 2>&1
status=$?
set -e
if [[ $status != 134 ]] || ! grep -Fq 'Touch retention must precede panel OFF commands' "$stage/before.log"; then
 cat "$stage/before.log"
 printf 'Original panel did not reach the required ordering assertion134\n' >&2
 exit 1
fi
printf 'Actual qualified11003 panel fails the independent early-blank assertion134\n'

patch -d "$profile" -p1 --fuzz=0 --dry-run -i "$addon/patches/display/0074-o82-touch-retain-before-off.patch"
patch -d "$profile" -p1 --fuzz=0 -i "$addon/patches/display/0074-o82-touch-retain-before-off.patch"
install -m644 "$panel" "$kernel/drivers/gpu/drm/panel/panel-xiaomi-o82.c"
cat > "$stage/asan-cc" <<'CC'
#!/usr/bin/env bash
set -Eeuo pipefail
exec "${UKE_PANEL_CC:?Pass the native compiler}" -fsanitize=address -fno-omit-frame-pointer "$@"
CC
chmod 700 "$stage/asan-cc"
export ASAN_OPTIONS=halt_on_error=1:abort_on_error=1:detect_leaks=1
export UBSAN_OPTIONS=halt_on_error=1:abort_on_error=1
for compiler in gcc clang; do
 CC=$compiler bash "$fixture" "$panel" "$header" "$kernel"
 UKE_PANEL_CC=$compiler CC=$stage/asan-cc bash "$fixture" "$panel" "$header" "$kernel"
done
printf 'Actual corrected panel: both suppliers/all7 modes, repeated retention, resume/remove, OFF errors/short writes, refusal and partial cleanup passed GCC/Clang UBSan and ASan\n'

# Qualify the existing final-ACK diagnostic on the exact retained protocol too.
protocol=$profile/src/input/nt36532-uke-protocol.c
printf '%s  %s\n' f81f42c2622a6eb671fd7ca11fbb0ce700b6f5a7589a43cb379b5baa7cdfb1ca "$protocol" | sha256sum -c --strict
printf '%s  %s\n' 05558c531e77d914f5dc1fbba8dda6fcde466f7f8b8451c7119955d9e389787d "$addon/src/input/nt36532-uke-protocol.c" | sha256sum -c --strict
install -m644 "$addon/src/input/nt36532-uke-protocol.c" "$protocol"
install -m644 "$protocol" "$kernel/drivers/input/touchscreen/nt36532-uke/nt36532-uke-protocol.c"
bash "$profile/tests/touch-gesture-ack-regression.sh"
for compiler in gcc clang; do
 CC=$compiler UKE_TOUCH_SANITIZE= bash "$profile/tests/touch-protocol-contract.sh"
 CC=$compiler UKE_TOUCH_SANITIZE=1 bash "$profile/tests/touch-protocol-contract.sh"
done
printf 'Candidate panel/fixture/protocol SHA256:\n'
sha256sum "$panel" "$fixture" "$protocol"
printf 'Source/callback fixture qualification only; complete kernel/module build, signed DNF delivery and physical touch/wake acceptance remain open\n'
