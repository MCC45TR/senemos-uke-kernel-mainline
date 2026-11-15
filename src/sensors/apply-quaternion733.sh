#!/usr/bin/bash
# COPR only, after the admitted full14 source preparation.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
work=$kernel/native-generated/ssc-quaternion733
contract=$profile/manifests/ssc-quaternion-20261110.json
[[ ! -e $work ]]
mkdir -p "$work/before" "$work/inverse"
while IFS=$'\t' read -r file before after;do
 [[ $file != /* && $file != *..* ]]
 printf '%s  %s\n' "$before" "$kernel/$file" | sha256sum -c --strict --quiet -
 install -Dm644 "$kernel/$file" "$work/before/$file"
done < <(jq -r '.source_units[]|[.path,.before_sha256,.after_sha256]|@tsv' "$contract")
for patch in src/sensors/0014-ssc-quaternion-input.patch src/sensors/0015-ssc-quaternion-native-dt.patch;do
 git -C "$kernel" apply --check --whitespace=error "$profile/$patch"
 git -C "$kernel" apply --whitespace=error "$profile/$patch"
done
while IFS=$'\t' read -r file after;do
 printf '%s  %s\n' "$after" "$kernel/$file" | sha256sum -c --strict --quiet -
 install -Dm644 "$kernel/$file" "$work/inverse/$file"
done < <(jq -r '.source_units[]|[.path,.after_sha256]|@tsv' "$contract")
git -C "$work/inverse" init -q
for patch in src/sensors/0015-ssc-quaternion-native-dt.patch src/sensors/0014-ssc-quaternion-input.patch;do git -C "$work/inverse" apply -R --whitespace=error "$profile/$patch";done
while IFS= read -r file;do cmp "$work/before/$file" "$work/inverse/$file";done < <(jq -r '.source_units[].path' "$contract")
(cd "$kernel";jq -r '.source_units[].path' "$contract" | xargs sha256sum) > "$work/applied.sha256"
printf 'Native quaternion source: all four full-unit inverses pass; existing resource ownership retained.\n'
