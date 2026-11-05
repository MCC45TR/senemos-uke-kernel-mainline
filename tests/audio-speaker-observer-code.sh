#!/usr/bin/env bash
# COPR only: compare actual observer instructions in relocatable kernel ELFs.
# No object/module is loaded or executed. A final-module build is not required.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
extract() {
 local input=$1 output=$2 address section size extra
 readelf -h "$input" | grep -Eq 'Type: +REL '
 readelf -h "$input" | grep -Eq 'Machine: +AArch64'
 objdump -t "$input" | awk '$3=="F" && $NF=="fs19xx_state_get" {print $1,$4,$5}' > "$work/symbol"
 [[ $(wc -l < "$work/symbol") == 1 ]]
 read -r address section size extra < "$work/symbol"
 [[ -z ${extra:-} && $address =~ ^[0-9a-fA-F]+$ && $size =~ ^[0-9a-fA-F]+$ && $section =~ ^[.a-zA-Z0-9_-]+$ ]]
 address=$((16#$address)); size=$((16#$size))
 [[ $size -gt 0 && $size -le 16384 && $address -ge 0 ]]
 objcopy --dump-section "$section=$work/section" "$input" "$work/repacked.o"
 [[ $(stat -c %s "$work/section") -ge $((address+size)) ]]
 dd if="$work/section" of="$output" bs=1 skip="$address" count="$size" status=none
}
extract "$1" "$work/expected"
extract "$2" "$work/linked"
if ! cmp -s "$work/expected" "$work/linked"; then
 echo 'Speaker inclusion: linked observer differs from the freshly compiled runtime object' >&2
 exit 1
fi
printf '%s\n' 'Speaker observer instructions match the runtime object; no module loaded.'
