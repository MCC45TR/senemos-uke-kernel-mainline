#!/usr/bin/bash
# COPR source worker only; retain every native16 source input and check.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result" "$work/parent" "$work/camera-owner734"
curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11336575 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-16"' "$work/state.json" >/dev/null
url=$(jq -er '.source_package.url' "$work/state.json")
[[ $url == https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/srpm-builds/11336575/uke-kernel-migration-check-7.3.4-16.src.rpm ]]
curl -qfsSL --max-time 600 --max-filesize 209715200 "$url" -o "$work/parent.src.rpm"
printf '%s  %s\n' 7971d5a6169d8fb67dbfca87ef34561a5341dae2811bae609a48f19a3e3f8959 "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;count++}END{if(bad||count!=21)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-camera-owner734.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
for path in src/camera/camcc-sm7675.c src/camera/provider/{apply-crm-owner734.sh,camcc-sm7675-crm-owner.h,camcc-sm7675-crm-rom.h,camcc-sm7675-crm-startup.h,camcc-sm7675-crm-floor.h,camcc-sm7675-crm-core.h,camcc-sm7675-crm-lut.h,camcc-sm7675-crm-passive.h,camcc-sm7675-crm-pm.h,camcc-sm7675-crm-transport.h} tests/{native-camera-owner734.sh,camcc-crm-owner.sh,camcc-crm-rom.sh,camcc-crm-startup.sh,camcc-crm-floor.sh} tests/fixtures/{camcc-crm-owner-model.h,camera-crm-transport-check.c,camcc-crm-rom-check.c,camcc-crm-startup-check.c,camcc-crm-floor-check.c};do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$work/camera-owner734/$path"
done
git -C "$owner" rev-parse HEAD > "$work/camera-owner734/source-commit"
(cd "$work/camera-owner734";find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/layer.sha256"
mv "$work/layer.sha256" "$work/camera-owner734/SHA256SUMS"
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-camera-owner734.tar.xz" -C "$work" camera-owner734
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
printf 'Complete native16 retained; permanent camera IRQ/PM/ROM qualification and actual ARM64 adapters queued. No Image or full release reserved.\n'
