#!/usr/bin/bash
set -Eeuo pipefail
export LC_ALL=C
umask 077

[[ $# == 1 ]]
out=$(realpath -m -- "$1")
assets=$(cd -- "$(dirname -- "$0")" && pwd)
version_script="$assets/../../native/normal-kernel-release.sh"
plan="$assets/release-plan.json"
package=senemos-uke-linux-kernel-mainline
project=uke-linux-unstable
chroot=fedora-rawhide-aarch64
api=https://copr.fedorainfracloud.org/api_3
repo=https://download.copr.fedorainfracloud.org/results/mcc45tr/$project
key=2204a661ea630a5303500085538797e72a3e4eca

read -r build parent_name parent_sha < <(jq -er --arg package "$package" '
    select(.parent_build|type=="number" and .==floor and .>=1) |
    select(.parent_sha256|test("^[a-f0-9]{64}$")) |
    select(.parent_filename|test("^"+$package+"-[0-9][0-9.]*-[0-9]+[.]fc[0-9]+[.]src[.]rpm$")) |
    [.parent_build,.parent_filename,.parent_sha256]|@tsv' "$plan")
job=$(curl -qfsSL --proto '=https' --max-time 20 "$api/build-chroot?build_id=$build&chrootname=$chroot")
result=$(jq -er --arg prefix "$repo/$chroot/$build-$package/" '
    select(.state=="succeeded" and .result_url==$prefix).result_url' <<< "$job")

work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS,trust}
curl -qfsSL --proto '=https' --retry 2 --max-time 30 --max-filesize 16384 \
    "$repo/pubkey.gpg" -o "$work/key.gpg"
fingerprint=$(gpg --batch --with-colons --show-keys "$work/key.gpg" |
    awk -F: '$1=="fpr" && !seen++ { print tolower($10) }')
[[ $fingerprint == "$key" ]]
rpmkeys --dbpath "$work/trust" --import "$work/key.gpg"
parent=${UKE_COPR_PARENT_SRPM:-"$work/$parent_name"}
if [[ -z ${UKE_COPR_PARENT_SRPM:-} ]]; then
    curl -qfsSL --proto '=https' --retry 2 --max-time 240 --max-filesize 190000000 \
        "$result$parent_name" -o "$parent"
fi
printf '%s  %s\n' "$parent_sha" "$parent" | sha256sum -c --strict
rpmkeys --dbpath "$work/trust" --checksig -v "$parent" > "$work/parent-signatures.txt"
[[ $(grep -Fc "key fingerprint: $key: OK" "$work/parent-signatures.txt") == 2 ]]
! grep -Eq 'NOKEY|BAD|NOT OK' "$work/parent-signatures.txt"
read -r name parent_version parent_release < <(rpm -qp --dbpath "$work/trust" \
    --qf '%{NAME} %{VERSION} %{RELEASE}\n' "$parent")
[[ $name == "$package" && $parent_name == "$name-$parent_version-$parent_release.src.rpm" ]]
(cd "$work/SOURCES"; rpm2cpio "$parent" | cpio -id --quiet --no-absolute-filenames)

# The release plan contains the complete reviewed delta to this signed parent.
(cd "$assets/inputs"; sha256sum -c --strict SHA256SUMS)
spec="$work/SPECS/$package.spec"
mv -- "$work/SOURCES/$package.spec" "$spec"
(
    cd "$work"
    git apply --check --whitespace=error "$assets/inputs/parent.patch"
    git apply --whitespace=error "$assets/inputs/parent.patch"
)
cmp "$spec" "$assets/$package.spec"
[[ $(grep -Ec '^%global normal_parent_copr [1-9][0-9]*$' "$spec") == 1 ]]
grep -Fxq "%global normal_parent_copr $build" "$spec"
# Verify the inherited merged-package gate before handing off a source RPM.
read -r contract_hash _ < <(sha256sum "$work/SOURCES/normal-merged-contract.sh")
if ! grep -Fxq "    $contract_hash %{SOURCE398} | sha256sum -c --strict --quiet -" "$spec"; then
    printf 'Merged-package gate digest does not match Source398 in the spec.\n' >&2
    exit 1
fi
install -m644 "$assets/inputs/uke-mst-link-budget-guard73538.tar.xz" \
    "$assets/inputs/uke-dp-hpd-worker73538.tar.xz" "$work/SOURCES/"
read -r version revision release < <(bash "$version_script" \
    "$work/SOURCES/linux-$parent_version.tar.xz" "$parent_version" "$parent_release")
[[ $release == "$version-$revision" && $version == "$parent_version" ]]
[[ $(grep -Ec '^%global normal_rpm_release [1-9][0-9]*$' "$spec") == 1 ]]
sed -i "s/^%global normal_rpm_release .*/%global normal_rpm_release $revision/" "$spec"
[[ $(rpmspec --target aarch64 -q --srpm --qf '%{VERSION}\n' "$spec") == "$version" ]]
rpmspec --target aarch64 -P "$spec" > "$work/expanded.spec"
grep -Fxq "Provides: kernel-uname-r($release)" "$work/expanded.spec"

history=$(curl -qfsSL --proto '=https' --max-time 20 \
    "$api/build/list?ownername=mcc45tr&projectname=$project&packagename=$package&limit=30")
jq -e --arg release "$release" --arg build "$build" '
    (.items|type=="array") and any(.items[]; ((.id|tostring)==$build and .state=="succeeded")) and
    (any(.items[]; .source_package.version==$release and .state=="succeeded")|not)
' <<< "$history" >/dev/null

rpmbuild -bs --define "_topdir $work" "$spec"
rpm_release=$(rpmspec -q --srpm --qf '%{RELEASE}' "$spec")
mkdir -p "$out"
install -m644 "$work/SRPMS/$package-$version-$rpm_release.src.rpm" "$out/"
printf 'Prepared Linux %s, normal release %s, ABI %s.\n' "$version" "$revision" "$release"
