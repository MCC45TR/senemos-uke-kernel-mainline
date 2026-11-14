#!/usr/bin/bash
# COPR only: retain the full23 historical reference preparation and context.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative kernel}")
out=$(realpath -m "${2:?Native output}")
profile=$kernel/native-profile
work=$kernel/native-generated/storage-cohort-history733
[[ ! -e $work ]]
mkdir "$work"
for role in cdsp waydroid cdsp-before;do
 ref=$kernel/native-generated/nfc-$role-reference
 [[ -s $ref/.config ]]
 # The unmodified full23 prefix resolved these with the actual compiler and
 # embedded-initramfs context. Preserve it for the original whole-config hash.
 grep -Fx "CONFIG_INITRAMFS_SOURCE=\"$out/boot-initramfs.cpio.gz\"" "$ref/.config"
 cp "$ref/.config" "$work/$role.config"
done
bash "$profile/tests/cdsp-pogo-toolchain-contract.sh" "$work/cdsp-before.config"
bash "$profile/tests/cdsp-pogo-config-contract.sh" "$work/cdsp-before.config"
bash "$profile/tests/governor-config-contract.sh" "$work/cdsp-before.config" "$work/cdsp.config"
(cd "$work";sha256sum cdsp.config waydroid.config cdsp-before.config) > "$work/accepted.sha256"
printf 'Historical storage cohort: actual full23 references pass original whole-config/toolchain/five refusals and governor gates; final compiler configs remain separate.\n'
