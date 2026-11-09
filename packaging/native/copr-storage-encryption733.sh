#!/usr/bin/bash
# Qualify standard storage encryption over the admitted cumulative source53.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 1 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result}")
manifest=$owner/manifests/storage-encryption-20261109.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
parent=$(jq -er .parent_commit "$manifest")
# Consume the immutable published SRPM. Re-running its source constructor would
# correctly refuse to generate the already published source53 version.
curl -qfsSL --retry 2 --max-time 180 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$work/parent.rpm") == uke-kernel-migration-check-7.3.3-53 ]]
rpm2cpio "$work/parent.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.rpm" | (cd "$output";cpio -idm --quiet --no-absolute-filenames)
spec=$output/uke-kernel-migration-check.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$spec" | sha256sum -c --strict --quiet -
version=$(jq -er .upstream.version "$owner/manifests/cumulative-release.json")
release=$(jq -er .source_check_release "$manifest")
native=senemos-native-profile-$version.tar.xz
tar -xJf "$output/$native" -C "$work"
tar -xJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile
boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
for tree in "$profile" "$boot";do
 while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
 install -Dm644 "$manifest" "$tree/manifests/storage-encryption-20261109.json"
done
awk -v release="$release" -v version="$version" '
 /^Release: 53%\{\?dist\}$/ {print "Release: " release "%{?dist}";r++;next}
 $0=="%install" {print "bash native-profile/packaging/native/check-storage-encryption733.sh \"$PWD\" %{_uke_out}";i++}
 $0=="%check" {
  print "install -m644 native-generated/storage-encryption733/candidate.config %{buildroot}%{_docdir}/%{name}/storage-encryption-candidate.config"
  print "install -m644 native-generated/storage-encryption733/delta.tsv %{buildroot}%{_docdir}/%{name}/storage-encryption-delta.tsv"
  k++
 }
 $0=="%changelog" {
  print;print "* Mon Nov 09 2026 Uke contributors - " version "-" release
  print "- Qualify standard FDE/FBE/inline encryption capability over source53."
  print "- Keep boot integration, keys and encrypted I/O acceptance separate."
  print "";c++;next
 }
 {print}
 END{if(r!=1||i!=1||c!=1||k!=1)exit 1}
' "$spec" > "$work/spec"
install -m644 "$work/spec" "$spec"
commit=$(git -C "$owner" rev-parse HEAD)
jq --arg parent "$parent" --arg commit "$commit" --arg version "$version" --argjson release "$release" '.+{
 source_commit:$commit,source_check_package:("uke-kernel-migration-check-"+$version+"-"+($release|tostring)),
 storage_encryption_parent_commit:$parent,storage_encryption_candidate_layer:1,
 storage_encryption_kernel_capabilities_requested:true,storage_encryption_raw_wrapped_policy_unchanged:true,
 storage_encryption_native_admitted:false,storage_encryption_encrypted_io_accepted:false,
 storage_encryption_tee_key_accepted:false,storage_encryption_boot_ready:false,
 storage_encryption_full_delivery_ready:false
}' "$profile/source-composition.json" > "$work/composition.json"
install -m644 "$work/composition.json" "$profile/source-composition.json"
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
install -m644 "$work/lock.json" "$boot/lock.json"
install -m644 "$work/lock.json" "$output/boot-payload.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/$native" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
printf 'Storage encryption capability candidate prepared over cumulative source53; actual crypto objects required, no volume/key/boot activation or new runtime family.\n'
