#!/usr/bin/bash
# Data-only:exact accepted archives/recipe/config;no make or target operations.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
profile=$(realpath "$1");parent_spec=$(realpath "$2")
contract=$owner/manifests/storage-config-delivery-20261111.json
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/tree"
for file in src/boot/build-payload.sh packaging/native/prepare-mst-power-delivery733.sh;do install -Dm644 "$profile/$file" "$work/tree/$file";done
bash "$owner/packaging/native/apply-storage-config-full733.sh" "$work/tree" "$contract"
for file in src/boot/build-payload.sh packaging/native/prepare-mst-power-delivery733.sh;do install -Dm644 "$work/tree/$file" "$work/accepted/$file";done
if bash "$owner/packaging/native/apply-storage-config-full733.sh" "$work/tree" "$contract" > "$work/reentry.log" 2>&1;then exit 1;fi
for file in src/boot/build-payload.sh packaging/native/prepare-mst-power-delivery733.sh;do cmp "$work/accepted/$file" "$work/tree/$file";done
for file in src/boot/build-payload.sh packaging/native/prepare-mst-power-delivery733.sh;do install -m644 "$profile/$file" "$work/tree/$file";done
printf '\n# modified parent\n' >> "$work/tree/src/boot/build-payload.sh"
cp "$work/tree/src/boot/build-payload.sh" "$work/bad-hook"
if bash "$owner/packaging/native/apply-storage-config-full733.sh" "$work/tree" "$contract" > "$work/hook-refusal.log" 2>&1;then exit 1;fi
cmp "$work/bad-hook" "$work/tree/src/boot/build-payload.sh"
jq '.full_release=24|.source_check_release=97' "$owner/manifests/cumulative-release.json" > "$work/plan.json"
bash "$owner/packaging/native/rewrite-storage-full733.sh" "$parent_spec" "$work/full.spec" "$contract" "$work/plan.json"
bash "$owner/tests/proximity-abi-recipe-scope.sh" "$work/full.spec"
for mutation in tuple proof parent;do
 cp "$work/plan.json" "$work/bad-plan.json";cp "$parent_spec" "$work/parent.spec"
 case $mutation in
  tuple) jq '.full_release=25' "$work/plan.json" > "$work/bad-plan.json";;
  proof) jq '.source_check_release=98' "$work/plan.json" > "$work/bad-plan.json";;
  parent) printf '\n# altered retained gate\n' >> "$work/parent.spec";;
 esac
 if bash "$owner/packaging/native/rewrite-storage-full733.sh" "$work/parent.spec" "$work/refused.spec" "$contract" "$work/bad-plan.json" > "$work/$mutation.log" 2>&1;then exit 1;fi
 [[ ! -e $work/refused.spec ]]
done
node "$owner/packaging/native/prepare-storage-config733.mjs" "$profile/native.config" "$owner/configs/storage-encryption733.config" "$owner/manifests/storage-config-layer-20261111.json" "$work/seed"
node "$owner/tests/storage-full-config-delta733.mjs" "$profile/native.config" "$work/seed/native.config" "$contract" "$work/delta.json"
for mutation in unrelated missing duplicate;do
 cp "$work/seed/native.config" "$work/config"
 case $mutation in
  unrelated) sed -i 's/^CONFIG_NR_CPUS=.*/CONFIG_NR_CPUS=4095/' "$work/config";;
  missing) sed -i 's/^CONFIG_CRYPTO_XTS=y$/CONFIG_CRYPTO_XTS=m/' "$work/config";;
  duplicate) printf 'CONFIG_FS_ENCRYPTION=y\n' >> "$work/config";;
 esac
 if node "$owner/tests/storage-full-config-delta733.mjs" "$profile/native.config" "$work/config" "$contract" "$work/refused.json" > "$work/$mutation-config.log" 2>&1;then exit 1;fi
 [[ ! -e $work/refused.json ]]
done
printf 'Storage full data:whole hook/recipe inverses,exact8 raw changes and8 altered/repeated input refusals pass;Kconfig/full link/runtime remain separate.\n'
