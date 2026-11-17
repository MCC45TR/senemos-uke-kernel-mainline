#!/usr/bin/bash
# COPR only. Retain all native23 source inputs and its entire recipe.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/parent" "$work/layer" "$work/qualified22"
curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11339509 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-23"' "$work/state.json" >/dev/null
url=$(jq -er '.source_package.url' "$work/state.json")
[[ $url == https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/srpm-builds/11339509/uke-kernel-migration-check-7.3.4-23.src.rpm ]]
curl -qfsSL --max-time 600 --max-filesize 209715200 "$url" -o "$work/parent.src.rpm"
printf '%s  %s\n' 1e989eba01f91e266b2cf82809894e09a6b7470c59b6929d6e45f9be98f606b3 "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;n++}END{if(bad||n!=23)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-camera-odd734.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec"
tar -xJf "$work/parent/uke-camera-owner734.tar.xz" -C "$work/qualified22"
(cd "$work/qualified22/camera-owner734";sha256sum -c --strict --quiet SHA256SUMS)
for path in tests/fixtures/camcc-crm-rom-check.c src/camera/provider/camcc-sm7675-crm-rom.h;do
 cmp "$owner/$path" "$work/qualified22/camera-owner734/$path"
done
mkdir "$result" "$work/layer/camera-odd734"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
layer=$work/layer/camera-odd734
for path in src/camera/rom-odd734/{apply.sh,pre.sha256,post.sha256,odd.patch} tests/native-camera-odd734.sh tests/fixtures/camera-rom-odd-check.c;do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$layer/$path"
done
git -C "$owner" rev-parse HEAD > "$layer/source-commit"
(cd "$layer";find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/layer.sha256"
mv "$work/layer.sha256" "$layer/SHA256SUMS"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/uke-camera-odd734.tar.xz" -C "$work/layer" camera-odd734
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
