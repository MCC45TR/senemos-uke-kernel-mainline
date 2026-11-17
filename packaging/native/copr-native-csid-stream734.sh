#!/usr/bin/bash
# COPR only: exact qualified native31 plus the common CSID stream lifecycle source check.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/parent" "$work/layer"
curl -qfsSL --retry 3 --retry-delay 3 --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11340606 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-31"' "$work/state.json" >/dev/null
url=$(jq -er '.source_package.url' "$work/state.json")
[[ $url == https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/srpm-builds/11340606/uke-kernel-migration-check-7.3.4-31.src.rpm ]]
curl -qfsSL --retry 3 --retry-delay 3 --max-time 600 --max-filesize 209715200 "$url" -o "$work/parent.src.rpm"
printf '%s  %s\n' 622e3d20adde5908c0be037cffb77a175505d504751d68572d31257c73e483d5 "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;n++}END{if(bad||n!=28)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-csid-stream734.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec"
layer=$work/layer/csid-stream734
mkdir -p "$layer/oracle"
for path in src/camera/csid-stream734/{apply.sh,pre.sha256,post.sha256,stream.patch} tests/native-csid-stream734.sh tests/fixtures/{csid-stream734-model.mjs,csid-stream734-check.c,csid-stream734-mutants.mjs} manifests/csid-stream734-20261117.json;do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$layer/$path"
done
contract=$owner/manifests/csid-stream734-20261117.json
while IFS=$'\t' read -r name source_url digest;do
 [[ $name =~ ^[a-zA-Z0-9_.+-]+$ && $digest =~ ^[a-f0-9]{64}$ && $source_url == https://raw.githubusercontent.com/* ]]
 curl -qfsSL --retry 3 --retry-delay 3 --max-time 60 --max-filesize 1048576 "$source_url" -o "$layer/oracle/$name"
 printf '%s  %s\n' "$digest" "$layer/oracle/$name" | sha256sum -c --strict --quiet -
 printf '%s  %s\n' "$digest" "$name" >> "$layer/oracle/SHA256SUMS"
done < <(jq -er '.oracle_sources[]|[.name,.url,.sha256]|@tsv' "$contract")
[[ $(wc -l < "$layer/oracle/SHA256SUMS") == 1 ]]
git -C "$owner" rev-parse HEAD > "$layer/source-commit"
(cd "$layer";find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/layer.sha256"
mv "$work/layer.sha256" "$layer/SHA256SUMS"
mkdir "$result"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/uke-csid-stream734.tar.xz" -C "$work/layer" csid-stream734
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
