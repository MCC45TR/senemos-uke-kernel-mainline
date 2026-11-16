#!/usr/bin/bash
# COPR source worker only; no compilation, full reservation or device operation.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
contract=$owner/manifests/native-abm734-20261116.json
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result" "$work/parent" "$work/keyring" "$work/gnupg" "$work/abm734"
curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11332099 > "$work/state.json"
jq -e '.state=="succeeded" and .source_package.version=="7.3.4-13"' "$work/state.json" >/dev/null
curl -qfsSL --max-time 600 --max-filesize 209715200 "$(jq -er .parent.srpm_url "$contract")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent.srpm_sha256 "$contract")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;count++}END{if(bad||count!=16)exit 1}' "$work/paths"
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
curl -qfsSL --max-time 90 --max-filesize 1048576 "$(jq -er .parent.proof_url "$contract")" -o "$result/native13-parent-proof.rpm"
printf '%s  %s\n' "$(jq -er .parent.proof_sha256 "$contract")" "$result/native13-parent-proof.rpm" | sha256sum -c --strict --quiet -
curl -qfsSL --max-time 45 --max-filesize 65536 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/key.asc"
fingerprint=$(GNUPGHOME="$work/gnupg" gpg --batch --with-colons --show-keys "$work/key.asc" 2>/dev/null | awk -F: '$1=="fpr"{print tolower($10);exit}')
[[ $fingerprint == $(jq -er .parent.signer_fingerprint "$contract") ]]
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --import "$work/key.asc"
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --checksig --verbose "$result/native13-parent-proof.rpm" > "$work/signatures"
[[ $(grep -Eic 'signature.*: OK$' "$work/signatures") == 2 ]]
! grep -Eiq 'NOTFOUND|NOKEY|BAD|NOT OK' "$work/signatures"
(cd "$work/parent";find . -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum) > "$work/retained.sha256"
bash "$owner/packaging/native/fold-native-abm734-check.sh" "$work/parent/uke-kernel-migration-check.spec" "$work/new.spec" "$contract"
cp -a "$work/parent/." "$result/"
install -m644 "$work/new.spec" "$result/uke-kernel-migration-check.spec"
for path in src/display/0077-o82-live-abm734.patch src/display/apply-native-abm734.sh src/display/abm734-parent.sha256 src/display/abm734-post.sha256 tests/native-abm734.sh tests/native-abm734.c;do
 [[ -f $owner/$path && ! -L $owner/$path ]]
 install -Dm644 "$owner/$path" "$work/abm734/$path"
done
printf '%s  %s\n' "$(jq -er .patch_sha256 "$contract")" "$work/abm734/src/display/0077-o82-live-abm734.patch" | sha256sum -c --strict --quiet -
git -C "$owner" rev-parse HEAD > "$work/abm734/layer-source-commit"
(cd "$work/abm734";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-native-abm734.tar.xz" -C "$work" abm734
install -m644 "$contract" "$result/"
(cd "$result";sha256sum -c --strict --quiet "$work/retained.sha256")
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$result/uke-kernel-migration-check.spec") == uke-kernel-migration-check-7.3.4-14.fc46 ]]
printf 'Native14 assembled from exact native13 sources and signed proof; no full kernel release or device update.\n'
