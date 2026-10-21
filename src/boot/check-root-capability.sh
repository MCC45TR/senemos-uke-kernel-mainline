#!/usr/bin/env bash
# Host-only check of the explicit little-endian ELF note in an Image or object.
set -Eeuo pipefail
[[ $# == 1 && -s $1 && -f $1 ]] || exit 2
image=$1
descriptor='root-selector-v1;userdata=f2fs;slot=a,b;vrr-min=0,30'
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
refuse() { echo 'Missing, duplicate or malformed Uke root-selector capability note' >&2; exit 1; }
le32() {
    local number=$1 octal
    printf -v octal '\\%03o\\%03o\\%03o\\%03o' "$((number & 255))" \
        "$((number >> 8 & 255))" "$((number >> 16 & 255))" "$((number >> 24 & 255))"
    printf '%b' "$octal"
}
length=$(printf '%s' "$descriptor" | wc -c)
{
    le32 4
    le32 "$((length + 1))"
    le32 "$((0x554b4501))"
    printf 'UKE\0%s\0' "$descriptor"
    head -c "$(((4 - (length + 1) % 4) % 4))" /dev/zero
} > "$work/expected"
# Limit the result to two occurrences; one complete aligned note is required.
matches=$(LC_ALL=C grep -aFob -- "$descriptor" "$image" | head -n 2 || :)
[[ -n $matches && $matches != *$'\n'* ]] || refuse
offset=$(printf '%s\n' "$matches" | cut -d: -f1)
[[ $offset =~ ^[0-9]+$ ]] || refuse
((offset >= 16 && (offset - 16) % 4 == 0)) || refuse
size=$(wc -c < "$work/expected")
dd if="$image" bs=1 skip="$((offset - 16))" count="$size" status=none |
    cmp -s - "$work/expected" || refuse
printf 'Uke root-selector ELF note v1: passed (declaration only, no VRR qualification)\n'
