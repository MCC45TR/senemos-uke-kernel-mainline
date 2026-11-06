#!/usr/bin/env bash
# COPR only. Exercise the actual production codec; no device or firmware access.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 && -x $1 ]]
codec=$(realpath "$1")
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
cd "$work"
truncate -s 64 Image
printf '\100\000\000\000\000\000\000\000' | dd of=Image bs=1 seek=16 conv=notrunc status=none
printf '\101\122\115\144' | dd of=Image bs=1 seek=56 conv=notrunc status=none
for profile in default linux userdata;do
 selector=();[[ $profile == default ]] || selector=("$profile")
 "$codec" create Image "canonical-$profile" "${selector[@]}"
 "$codec" create-bootloader-compat Image "compat-$profile" "${selector[@]}"
 "$codec" inspect "canonical-$profile" | jq -e '.os_version_encoded==0' >/dev/null
 "$codec" inspect "compat-$profile" | jq -e '.os_version_encoded==570425768 and .header_version==4 and .kernel_bytes==64 and .ramdisk_bytes==0 and .signature_bytes==0 and (.avb_footer_present|not) and .image_bytes==100663296' >/dev/null
 # Only the four version bytes may differ; payload, selector and padding remain.
 cmp -n 16 "canonical-$profile" "compat-$profile"
 cmp -i 20:20 "canonical-$profile" "compat-$profile"
 "$codec" extract "compat-$profile" "readback-$profile"
 cmp Image "readback-$profile"
done
reject(){ if "$codec" "$@" > refusal.stdout 2> refusal.stderr;then echo 'Unsafe compatibility input accepted' >&2;exit 1;fi; }
reject create-bootloader-compat Image injected 'userdata root=/dev/unsafe'
reject create-bootloader-compat Image empty ''
reject create-bootloader-compat Image foreign-profile system
reject create-bootloader-compat Image compat-default
ln -s never-created symlink
reject create-bootloader-compat Image symlink
cp Image foreign
printf '\000\000\000\000' | dd of=foreign bs=1 seek=56 conv=notrunc status=none
reject create-bootloader-compat foreign wrong-arch
cp Image big-endian
printf '\001' | dd of=big-endian bs=1 seek=24 conv=notrunc status=none
reject create-bootloader-compat big-endian wrong-endian
reject create-bootloader-compat /dev/null device
mkfifo fifo
reject create-bootloader-compat fifo fifo-output
printf 'Explicit Uke bootloader compatibility: three profiles, exact four-byte delta, unchanged Image, canonical zero mode and refusal controls passed\n'
