#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "$1");out=$(realpath -m "$2")
profile=$kernel/native-profile
contract=$profile/manifests/battery-event-health-20261111.json
work=$kernel/native-generated/battery-event-health733
file=drivers/power/supply/qcom_battmgr.c
[[ ! -e $work ]]
mkdir -p "$work/before/$(dirname "$file")"
printf '%s  %s\n' "$(jq -er '.source_units[0].before_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
cp "$kernel/$file" "$work/before/$file"
while IFS= read -r patch;do git -C "$kernel" apply --check --whitespace=error "$profile/$patch";git -C "$kernel" apply --whitespace=error "$profile/$patch";done < <(jq -r '.patches[]' "$contract")
printf '%s  %s\n' "$(jq -er '.source_units[0].after_sha256' "$contract")" "$kernel/$file" | sha256sum -c --strict --quiet -
mkdir -p "$work/inverse/$(dirname "$file")"
cp "$kernel/$file" "$work/inverse/$file"
while IFS= read -r patch;do git -C "$work/inverse" apply -R --whitespace=error "$profile/$patch";done < <(jq -r '.patches|reverse[]' "$contract")
cmp "$work/before/$file" "$work/inverse/$file"
for cc in gcc clang;do
 for sanitize in 0 1;do CC=$cc SANITIZE=$sanitize bash "$profile/tests/battery-event-health.sh" "$kernel/$file";done
done
# Each complete old behavior must fail, not merely compile with stale values.
ulimit -c 0
for patch in $(jq -r '.patches[]' "$contract");do
 bad=$work/refused-$(basename "$patch" .patch)
 mkdir -p "$bad/$(dirname "$file")"
 cp "$kernel/$file" "$bad/$file"
 git -C "$bad" apply -R --whitespace=error "$profile/$patch"
 status=0
 CC=gcc SANITIZE=0 bash "$profile/tests/battery-event-health.sh" "$bad/$file" > "$bad/result.log" 2>&1 || status=$?
 [[ $status == 134 ]]
 printf 'Previous battery behavior refused:%s/status%s.\n' "$(basename "$patch")" "$status"
done
make -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 LOCALVERSION=-19-unstable KCFLAGS=-Werror W=1 -j4 drivers/power/supply/qcom_battmgr.o
object=$out/drivers/power/supply/qcom_battmgr.o
llvm-readelf -h "$object" | grep -F AArch64
(cd "$kernel";sha256sum "$file") > "$work/applied.sha256"
printf 'Actual battery event/health native: whole full19 inverse,four callback modes,two previous-behavior refusals and fresh ARM64 battery object; no electrical acceptance.\n'
