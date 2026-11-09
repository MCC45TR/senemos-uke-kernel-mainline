#!/usr/bin/bash
# COPR only: real worker/STOP callbacks and a fresh ARM64 codec object.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath "${2:?Existing native output}")
profile=$kernel/native-profile
codec=$kernel/sound/soc/codecs/fs19xx.c
patch=$profile/src/audio/0031-fs19xx-freezable-health.patch
work=$kernel/native-generated/audio-freeze733
[[ ! -e $work ]]
mkdir -p "$work/inverse/sound/soc/codecs"
ulimit -c 0
printf '%s  %s\n' 7259901dd2d2121d816e7084142ae55fcfe5838a3f5e70affbe42e8dbd55b319 "$codec" | sha256sum -c --strict --quiet -
cp "$codec" "$work/before.c"
git -C "$kernel" apply --check --whitespace=error "$patch"
git -C "$kernel" apply --whitespace=error "$patch"
[[ $(grep -Fc 'mod_delayed_work(system_freezable_wq, &fs19xx->unmute_work,' "$codec") == 5 ]]
! grep -F 'mod_delayed_work(system_percpu_wq, &fs19xx->unmute_work,' "$codec"
cp "$codec" "$work/inverse/sound/soc/codecs/fs19xx.c"
git -C "$work/inverse" apply -R --whitespace=error "$patch"
cmp "$work/before.c" "$work/inverse/sound/soc/codecs/fs19xx.c"
for cc in gcc clang;do
 for san in 0 1;do
  for ticks in 100 250 1000;do
   CC=$cc SANITIZE=$san TICKS=$ticks FREEZABLE=1 bash "$profile/tests/audio-stop-deadline.sh" "$kernel"
   printf 'Actual freezable audio worker passed:%s/sanitize%s/HZ%s; system sleep acceptance separate.\n' "$cc" "$san" "$ticks"
  done
 done
 # The identical provider must reject the old nonfreezable scheduling sites.
 git -C "$kernel" apply -R --whitespace=error "$patch"
 status=0
 CC=$cc SANITIZE=0 TICKS=100 FREEZABLE=1 bash "$profile/tests/audio-stop-deadline.sh" "$kernel" > "$work/$cc-old-queue-refusal.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 grep -F '!queue' "$work/$cc-old-queue-refusal.log"
 git -C "$kernel" apply --whitespace=error "$patch"
 printf 'Historical nonfreezable audio queue refused:%s/status134.\n' "$cc"
done
release=$(jq -er .full_release "$profile/manifests/cumulative-release.json")
find "$out/sound/soc/codecs" -maxdepth 1 -type f -name fs19xx.o -delete
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION="-$release-unstable" KCFLAGS=-Werror W=1 -j4 sound/soc/codecs/fs19xx.o
llvm-readelf -h "$out/sound/soc/codecs/fs19xx.o" | grep -F AArch64
llvm-nm -u "$out/sound/soc/codecs/fs19xx.o" > "$work/undefined-symbols.txt"
grep -E '[[:space:]]U[[:space:]]+system_freezable_wq$' "$work/undefined-symbols.txt"
! grep -E '[[:space:]]U[[:space:]]+system_percpu_wq$' "$work/undefined-symbols.txt"
printf 'Actual ARM64 FS19xx uses the system freezable queue at all five sites; full-source inverse retains registers, gain and fault paths. No physical suspend acceptance.\n'
