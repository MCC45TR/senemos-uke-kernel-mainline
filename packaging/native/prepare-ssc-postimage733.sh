#!/usr/bin/bash
# Source-check only. Reproduce the late full24 SSC postimage without a full build.
set -Eeuo pipefail
[[ ! -e /etc/senemos/kernel-update.conf && $# == 1 ]]
kernel=$(realpath "$1")
profile=$kernel/native-profile
relative=drivers/iio/common/uke-ssc
work=$kernel/native-generated/ssc-freshness-postimage
[[ ! -e $work ]]
printf '%s  %s\n' c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd "$kernel/$relative/uke-ssc-iio.c" | sha256sum -c --strict --quiet -
mkdir -p "$work/$relative"
git -C "$work" init -q
for file in uke-ssc-iio.c uke-ssc-protocol.c uke-ssc-protocol.h Kconfig Makefile;do
 install -m644 "$kernel/$relative/$file" "$work/$relative/"
done
for number in 0004 0005 0006 0007 0008 0009 0010 0011 0012 0013 0014 0015 0016 0017 0018;do
 patches=("$profile/src/sensors/$number"-*.patch)
 [[ ${#patches[@]} == 1 && -f ${patches[0]} ]]
 git -C "$work" apply --check --whitespace=error --include="$relative/*" "${patches[0]}"
 git -C "$work" apply --whitespace=error --include="$relative/*" "${patches[0]}"
done
printf '%s  %s\n' f7c689e893e8696dcf093cf859dbb07dfc6b31b5332ce4108a19be13252efca1 "$work/$relative/uke-ssc-iio.c" | sha256sum -c --strict --quiet -
for file in uke-ssc-protocol.c uke-ssc-protocol.h Makefile;do cmp "$kernel/$relative/$file" "$work/$relative/$file";done
for file in uke-ssc-iio.c Kconfig;do install -m644 "$work/$relative/$file" "$kernel/$relative/";done
for header in uke-ssc-dual-light.h uke-ssc-proximity-input.h uke-ssc-heading.h uke-ssc-heading-input.h;do
 install -m644 "$profile/src/sensors/$header" "$kernel/$relative/"
done
(cd "$kernel"; sha256sum "$relative"/*) > "$work/assembled.sha256"
printf 'Exact full24 late SSC driver reproduced from prepared preimage and15 retained source patches; protocol and Makefile unchanged\n'
