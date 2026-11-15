#!/usr/bin/bash
# Data fixtures only. No compiler, Kconfig, package transaction or device I/O.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
parent=$(realpath "${1:?Exact full23 native profile}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$stage/profile/manifests" "$stage/profile/configs"
profile=$stage/profile
cp "$owner/manifests/storage-cohort-20261111.json" "$profile/manifests/"
cp "$owner/configs/storage-encryption733.config" "$profile/configs/"
while IFS= read -r file;do
 install -Dm644 "$parent/$file" "$profile/$file"
done < <(jq -r '.profiles[].path' "$profile/manifests/storage-cohort-20261111.json")
node "$owner/tests/storage-cohort733.mjs" seed "$profile" "$stage/cohort"
while IFS=$'\t' read -r role file;do
 mkdir "$stage/cohort/before-$role" "$stage/cohort/after-$role"
 cp "$profile/$file" "$stage/cohort/before-$role/.config"
 cp "$stage/cohort/seed-$role/.config" "$stage/cohort/after-$role/.config"
done < <(jq -r '.profiles[]|[.role,.path]|@tsv' "$profile/manifests/storage-cohort-20261111.json")
# Exercise the comparison using raw-data fixtures, not resolved configs.
node "$owner/tests/storage-cohort733.mjs" verify "$profile" "$stage/cohort" > "$stage/good.log"
for mutation in unrelated governor retained duplicate;do
 file=$stage/cohort/after-cdsp/.config
 cp "$file" "$stage/accepted.config"
 case $mutation in
 unrelated) sed -i 's/^CONFIG_NR_CPUS=.*/CONFIG_NR_CPUS=4095/' "$file";;
 governor) sed -i 's/^CONFIG_CPU_FREQ_GOV_POWERSAVE=y$/CONFIG_CPU_FREQ_GOV_POWERSAVE=m/' "$file";;
 retained) sed -i 's/^CONFIG_MODULE_SIG_FORCE=y$/# CONFIG_MODULE_SIG_FORCE is not set/' "$file";;
 duplicate) printf 'CONFIG_FS_ENCRYPTION=y\n' >> "$file";;
 esac
 ! cmp -s "$file" "$stage/accepted.config"
 if node "$owner/tests/storage-cohort733.mjs" verify "$profile" "$stage/cohort" > "$stage/$mutation.log" 2>&1;then
  printf 'Storage cohort admitted mutation:%s\n' "$mutation" >&2;exit 1
 fi
 cp "$stage/accepted.config" "$file"
done
cp "$profile/native.config" "$stage/native.config"
printf 'CONFIG_FS_ENCRYPTION=y\n' >> "$profile/native.config"
if node "$owner/tests/storage-cohort733.mjs" seed "$profile" "$stage/bad-seed" > "$stage/bad-seed.log" 2>&1;then
 echo 'Changed parent admitted by seed generator' >&2;exit 1
fi
[[ ! -e $stage/bad-seed ]]
cp "$stage/native.config" "$profile/native.config"
printf 'Storage cohort data fixtures passed: four seeds,complete map comparison,five refusals; Kconfig and ARM64 remain unqualified.\n'
