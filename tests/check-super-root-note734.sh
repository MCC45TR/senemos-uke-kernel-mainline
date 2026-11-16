#!/usr/bin/bash
# Exact little-endian capability note, following the existing root-note check.
set -Eeuo pipefail
[[ $# == 1 && -f $1 && -s $1 ]]
descriptor='super-root-v1;role=rescue;root=dm-uke-rescue;readonly;noresume;seed=4GiB'
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
le32() {
 local value=$1 octal
 printf -v octal '\\%03o\\%03o\\%03o\\%03o' "$((value&255))" "$((value>>8&255))" "$((value>>16&255))" "$((value>>24&255))"
 printf '%b' "$octal"
}
{
 le32 4;le32 "$((${#descriptor}+1))";le32 "$((0x554b4503))"
 printf 'UKE\0%s\0' "$descriptor"
 head -c "$(((4-(${#descriptor}+1)%4)%4))" /dev/zero
} > "$work/expected"
matches=$(LC_ALL=C grep -aFob -- "$descriptor" "$1" | head -n2 || :)
[[ -n $matches && $matches != *$'\n'* ]]
offset=${matches%%:*}
[[ $offset =~ ^[0-9]+$ ]]
((offset>=16&&(offset-16)%4==0))
dd if="$1" bs=1 skip="$((offset-16))" count="$(stat -c%s "$work/expected")" status=none | cmp - "$work/expected"
echo 'Uke super-root ELF note: exact declaration verified; boot and hardware remain unqualified.'
