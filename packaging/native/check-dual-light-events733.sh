#!/usr/bin/env bash
# Source-only milestone: actual reducer and real ARM64 compile, no driver claim.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
phase=${3:?prepared or objects}
[[ $phase == prepared || $phase == objects ]]
profile=$kernel/native-profile
if [[ $phase == prepared ]];then
 for cc in gcc clang;do
  for sanitize in 0 1;do
   CC=$cc SANITIZE=$sanitize bash "$profile/tests/ssc-dual-light-events.sh"
  done
 done
 printf 'Dual-light event reducer source gate passed; twelve mutants and original source24 replay refused. SSC/Hall/IIO/DDC integration and hardware parity remain pending.\n'
 exit 0
fi
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -m644 "$profile/tests/ssc-dual-light-native.c" "$work/ssc-dual-light-proof.c"
printf 'obj-m += ssc-dual-light-proof.o\nccflags-y += -I%s/src/sensors\n' "$profile" > "$work/Makefile"
make -s -C "$kernel" O="$out" M="$work" ARCH=arm64 LLVM=1 LLVM_IAS=1 W=1 ssc-dual-light-proof.o
llvm-readelf -h "$work/ssc-dual-light-proof.o" | grep -E 'Machine:.*AArch64'
llvm-nm "$work/ssc-dual-light-proof.o" | grep -E ' T uke_ssc_light_native_proof$'
printf '%s  %s\n' c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c" | sha256sum -c --strict --quiet -
printf 'Actual AArch64 reducer compile consumer passed; cumulative SSC driver remains byte-exact. Not a registered endpoint or monitor feature.\n'
