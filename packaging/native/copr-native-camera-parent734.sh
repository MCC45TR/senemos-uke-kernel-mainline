#!/usr/bin/bash
# COPR only. Retain the complete qualified native24 source and recipe.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/parent" "$work/layer" "$work/qualified22" "$work/passive"
curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11339733 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-24"' "$work/state.json" >/dev/null
url=$(jq -er '.source_package.url' "$work/state.json")
[[ $url == https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/srpm-builds/11339733/uke-kernel-migration-check-7.3.4-24.src.rpm ]]
curl -qfsSL --max-time 600 --max-filesize 209715200 "$url" -o "$work/parent.src.rpm"
printf '%s  %s\n' f2a867d58b454b469fc664f6fcebb039a3b82655ea2e4721ba5be3100ba06067 "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;n++}END{if(bad||n!=24)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-camera-parent734.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec"
tar -xJf "$work/parent/uke-camera-owner734.tar.xz" -C "$work/qualified22"
(cd "$work/qualified22/camera-owner734";sha256sum -c --strict --quiet SHA256SUMS)
for path in tests/fixtures/{camcc-crm-native-check.c,camcc-native-check.c};do cmp "$owner/$path" "$work/qualified22/camera-owner734/$path";done
tar -xJf "$work/parent/uke-crm-passive.tar.xz" -C "$work/passive"
for path in tests/{camcc-crm-passive.sh,camcc-crm-passive-catalog.mjs,fixtures/camcc-crm-passive-check.c};do cmp "$owner/$path" "$work/passive/crm-passive/$path";done
mkdir "$result" "$work/layer/camera-parent734"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
layer=$work/layer/camera-parent734
for path in src/camera/native-parent734/{apply.sh,pre.sha256,post.sha256,parent.patch} tests/native-camera-parent734.sh tests/fixtures/{camera-parent-model.mjs,camcc-crm-native-check.c,camcc-native-check.c,camcc-crm-passive-check.c} tests/{camcc-crm-passive.sh,camcc-crm-passive-catalog.mjs};do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$layer/$path"
done
git -C "$owner" rev-parse HEAD > "$layer/source-commit"
(cd "$layer";find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/layer.sha256"
mv "$work/layer.sha256" "$layer/SHA256SUMS"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/uke-camera-parent734.tar.xz" -C "$work/layer" camera-parent734
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
