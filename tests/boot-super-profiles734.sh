#!/usr/bin/bash
# Actual codec fixture only; no real Image, bootloader or device.
set -Eeuo pipefail
[[ $# == 1 && -x $1 ]]
codec=$(realpath "$1")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cd "$work"
descriptor='super-root-v1;role=rescue;root=dm-uke-rescue;readonly;noresume;seed=4GiB'
le32() {
 local value=$1 octal
 printf -v octal '\\%03o\\%03o\\%03o\\%03o' "$((value&255))" "$((value>>8&255))" "$((value>>16&255))" "$((value>>24&255))"
 printf '%b' "$octal"
}
{
 le32 4;le32 "$((${#descriptor}+1))";le32 "$((0x554b4503))"
 printf 'UKE\0%s\0' "$descriptor"
 head -c "$(((4-(${#descriptor}+1)%4)%4))" /dev/zero
} > note
truncate -s4096 Image
printf '\000\020\000\000\000\000\000\000' | dd of=Image bs=1 seek=16 conv=notrunc status=none
printf '\101\122\115\144' | dd of=Image bs=1 seek=56 conv=notrunc status=none
cp Image old-kernel
dd if=note of=Image bs=1 seek=64 conv=notrunc status=none
for profile in userdata-super rescue;do
 case $profile in
  userdata-super) selector='senemos.root=userdata senemos.super=seed4-v1';;
  rescue) selector='senemos.root=userdata senemos.role=rescue';;
 esac
 "$codec" create Image canonical "$profile"
 "$codec" create-bootloader-compat Image compat "$profile"
 [[ $(dd if=compat bs=1 skip=44 count=1536 status=none | tr -d '\000') == "$selector" ]]
 "$codec" inspect canonical | jq -e '.os_version_encoded==0 and .image_bytes==100663296' >/dev/null
 "$codec" inspect compat | jq -e '.os_version_encoded==570425768 and .ramdisk_bytes==0 and .signature_bytes==0 and (.avb_footer_present|not)' >/dev/null
 cmp -n16 canonical compat
 cmp -i20:20 canonical compat
 "$codec" extract compat readback
 cmp Image readback
 unlink canonical;unlink compat;unlink readback
done
reject() {
 if "$codec" create-bootloader-compat "$1" refused "$2" > refusal.log 2>&1;then echo 'Unsafe super boot header accepted' >&2;exit 1;fi
 [[ ! -e refused && ! -L refused ]]
}
reject old-kernel userdata-super
reject old-kernel rescue
for fault in type owner length padding duplicate text unaligned;do
 cp Image mutated
 case $fault in
  type) printf '\004' | dd of=mutated bs=1 seek=72 conv=notrunc status=none;;
  owner) printf X | dd of=mutated bs=1 seek=76 conv=notrunc status=none;;
  length) printf '\001' | dd of=mutated bs=1 seek=68 conv=notrunc status=none;;
  padding) printf X | dd of=mutated bs=1 seek="$((64+$(stat -c%s note)-1))" conv=notrunc status=none;;
  duplicate) dd if=note of=mutated bs=1 seek=512 conv=notrunc status=none;;
  text) printf '%s' "$descriptor" | dd of=mutated bs=1 seek=512 conv=notrunc status=none;;
  unaligned) cp old-kernel mutated;dd if=note of=mutated bs=1 seek=65 conv=notrunc status=none;;
 esac
 reject mutated userdata-super
 reject mutated rescue
 unlink mutated
done
reject Image 'rescue root=/dev/unsafe'
reject Image userdata-super-extra
echo 'PASS: boot super profiles: exact capability, two profiles, compatibility delta, payload identity and sixteen malformed/old-note refusals; no device'
