#!/usr/bin/bash
# COPR source assembly only. No full submission or release reservation here.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1"); qualification=$(realpath "$2")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
plan=$owner/manifests/stable734-20261115.json
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
jq -e '.schema_version==1 and .full_release==2 and .source_check.native_qualified==true and
 (.source_check.build|type=="number") and (.source_check.release|type=="number") and
 (.source_check.source_commit|test("^[a-f0-9]{40}$")) and
 (.source_check.srpm_sha256|test("^[a-f0-9]{64}$")) and
 (.source_check.receipt_sha256|test("^[a-f0-9]{64}$")) and
 .signer_fingerprint=="2204a661ea630a5303500085538797e72a3e4eca" and
 .full_kernel_built==false and .physical_acceptance==false' "$qualification" >/dev/null
id=$(jq -er .source_check.build "$qualification")
curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$id" > "$work/state.json"
check=$(jq -er .source_check.release "$qualification")
jq -e --arg version "7.3.4-$check" --arg url "$(jq -er .source_check.srpm_url "$qualification")" \
 '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and
 .source_package.version==$version and .source_package.url==$url' "$work/state.json" >/dev/null
curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build-chroot/$id/fedora-rawhide-aarch64" > "$work/chroot.json"
jq -e '.state=="succeeded"' "$work/chroot.json" >/dev/null
curl -qfsSL --max-time 45 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&packagename=senemos-uke-linux-kernel-mainline-unstable&limit=1000&order=id&order_type=DESC' > "$work/full-history.json"
[[ $(bash "$owner/scripts/kernel-release.sh" next-planned-full "$work/full-history.json" "$plan") == 2 ]]
curl -qfsSL --max-time 600 --max-filesize 314572800 "$(jq -er .source_check.srpm_url "$qualification")" -o "$work/source.src.rpm"
curl -qfsSL --max-time 180 --max-filesize 2097152 "$(jq -er .source_check.receipt_url "$qualification")" -o "$work/proof.rpm"
printf '%s  %s\n' "$(jq -er .source_check.srpm_sha256 "$qualification")" "$work/source.src.rpm" \
 "$(jq -er .source_check.receipt_sha256 "$qualification")" "$work/proof.rpm" | sha256sum -c --strict --quiet -
mkdir "$result" "$work/keyring" "$work/gnupg"
rpm2cpio "$work/source.src.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
rpm2cpio "$work/source.src.rpm" | (cd "$result";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
curl -qfsSL --max-time 60 --max-filesize 65536 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$result/stable734-copr-public-key.asc"
fingerprint=$(GNUPGHOME="$work/gnupg" gpg --batch --with-colons --show-keys "$result/stable734-copr-public-key.asc" 2>/dev/null | awk -F: '$1=="fpr"{print tolower($10);exit}')
[[ $fingerprint == "$(jq -er .signer_fingerprint "$qualification")" ]]
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --import "$result/stable734-copr-public-key.asc"
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --checksig --verbose "$work/proof.rpm" > "$work/signatures"
[[ $(grep -Eic 'signature.*: OK$' "$work/signatures") == 2 ]]
! grep -Eiq 'NOTFOUND|NOKEY|BAD|NOT OK' "$work/signatures"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' "$work/proof.rpm") == "uke-kernel-migration-check-7.3.4-$check.fc46.aarch64" ]]
install -m644 "$work/proof.rpm" "$result/stable734-native-proof.rpm"
install -m644 "$qualification" "$result/stable734-full-qualification.json"
# Retain every qualified source byte except the full recipe and three native
# profile metadata files. Runtime C, DT, firmware paths, configs and boot input
# archive remain the exact qualified source-check inputs.
curl -qfsSL --max-time 600 --max-filesize 314572800 "$(jq -er .parent_srpm_url "$plan")" -o "$work/full28.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$plan")" "$work/full28.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/full28.src.rpm" | cpio -i --to-stdout --quiet ./senemos-uke-linux-kernel-mainline-unstable.spec > "$work/full28.spec"
[[ -s $work/full28.spec ]]
bash "$owner/packaging/native/fold-stable734-full.sh" "$work/full28.spec" "$result/senemos-uke-linux-kernel-mainline-unstable.spec" "$plan"
unlink "$result/uke-kernel-migration-check.spec"
tar -xJf "$result/senemos-native-profile-7.3.4.tar.xz" -C "$work"
profile=$work/native-profile
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
[[ $(cat "$profile/source-commit") == "$(jq -er .source_check.source_commit "$qualification")" ]]
(cd "$profile";find . -type f ! -name SHA256SUMS ! -name source-commit ! -name source-composition.json -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-profile.sha256"
cp "$profile/source-composition.json" "$work/parent-composition.json"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --slurpfile q "$qualification" '.source_commit=$commit |
 .native_stable734_qualification=$q[0].source_check |
 .vrr_native_boot_default_layer=1 | .vrr_native_boot_default_hz=30 |
 .vrr_explicit_zero_and_saved_policy_preserved=true |
 .livepatch_requested=true | .livepatch_module_signature_force_retained=true |
 .livepatch_module_certificate_der_sha256="f1cbc20839f672145fb1c5d564b5e09e67d2272d7164d01e4123750442a7f1f8" |
 .rgb_status_reader_required_capability="uke-control(rgb-charge-status-v1)" |
 .livepatch_signed_patch_load_qualified=false |
 .vrr_native_physical_cadence_qualified=false' "$work/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/parent-composition.json" -e '. as $next | all($old[0]|to_entries[];.key=="source_commit" or $next[.key]==.value)' "$profile/source-composition.json" >/dev/null
(cd "$profile";sha256sum -c --strict --quiet "$work/retained-profile.sha256";
 find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/senemos-native-profile-7.3.4.tar.xz" -C "$work" native-profile
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$result/senemos-uke-linux-kernel-mainline-unstable.spec") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-2.fc46 ]]
printf 'Full7.3.4-2 source assembled from successful signed native qualification and exact full28 recipe; only source preparation, no submission or hardware acceptance.\n'
