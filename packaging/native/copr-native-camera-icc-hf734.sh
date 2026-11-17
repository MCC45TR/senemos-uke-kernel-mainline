#!/usr/bin/bash
# COPR source worker only; preserve every qualified33 source input.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/parent" "$work/layer"
curl -qfsSL --retry 3 --retry-delay 3 --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11341679 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-33"' "$work/state.json" >/dev/null
url=$(jq -er '.source_package.url' "$work/state.json")
[[ $url == https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/srpm-builds/11341679/uke-kernel-migration-check-7.3.4-33.src.rpm ]]
curl -qfsSL --retry 3 --retry-delay 3 --max-time 600 --max-filesize 209715200 "$url" -o "$work/parent.src.rpm"
printf '%s  %s\n' 6e4cbc6bbd263ee17aad9bbab549453eb04f977e9b85e0fa4be290f9e3c37238 "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;n++}END{if(bad||n!=30)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-camera-icc-hf734.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec"
layer=$work/layer/camera-icc-hf734
for path in src/camera/icc-hf734/{apply.sh,pre.sha256,post.sha256,icc.patch} tests/{native-camera-icc-hf734.sh,camera-icc-hf734-contract.sh} tests/fixtures/camera-icc-hf734.c manifests/camera-icc-hf734-20261118.json;do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$layer/$path"
done
mkdir "$layer/references"
curl -qfsSL --retry 3 --retry-delay 3 --max-time 90 --max-filesize 131072 \
 https://raw.githubusercontent.com/MiCode/Xiaomi_Kernel_OpenSource/5712080a4b0c0b1a879e6d145c601c649ddaddfd/drivers/interconnect/qcom/cliffs.c \
 -o "$layer/references/micode-cliffs.c"
printf '%s  %s\n' 20b50ed6d9b1e318ff0ac14f07827c102e5ab7cdcaa154008f9957c215b2fb79 "$layer/references/micode-cliffs.c" | sha256sum -c --strict --quiet -
git -C "$owner" rev-parse HEAD > "$layer/source-commit"
(cd "$layer";find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/layer.sha256"
mv "$work/layer.sha256" "$layer/SHA256SUMS"
mkdir "$result"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/uke-camera-icc-hf734.tar.xz" -C "$work/layer" camera-icc-hf734
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
