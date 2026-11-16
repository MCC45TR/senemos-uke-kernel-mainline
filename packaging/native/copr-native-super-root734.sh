#!/usr/bin/bash
# COPR source worker only. Assemble from the complete audited native14 inputs.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result" "$work/parent" "$work/super-root734"
curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11333196 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-14"' "$work/state.json" >/dev/null
curl -qfsSL --max-time 600 --max-filesize 209715200 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/srpm-builds/11333196/uke-kernel-migration-check-7.3.4-14.src.rpm -o "$work/parent.src.rpm"
printf '%s  %s\n' 5b0885f238a4a94941958063659dd267cfc0feb8b0aa3320f9688fea75bc705c "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;count++}END{if(bad||count!=19)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-super-root734.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
for path in src/boot/super-root734/uke-super-root-selector.h src/boot/super-root734/apply-source.sh tests/super-root734.cpp tests/native-super-root734.sh tests/check-super-root-note734.sh;do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$work/super-root734/$path"
done
git -C "$owner" rev-parse HEAD > "$work/super-root734/source-commit"
(cd "$work/super-root734";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-super-root734.tar.xz" -C "$work" super-root734
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
printf 'Complete native14 source retained; new prepared-root wrapper and two real ARM64 boot objects queued without Image or full release reservation.\n'
