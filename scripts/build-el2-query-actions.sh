#!/usr/bin/env bash
# Native build is restricted to the disposable Actions runner, never the tablet.
set -Eeuo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${GITHUB_REF:-} == refs/heads/kvm && $(uname -m) == aarch64 ]] || {
    echo 'Run this artifact-only producer in the kvm GitHub Actions job.' >&2; exit 78;
}
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
lock=$owner/manifests/el2-query-20261103.json
work=/tmp/uke-kvm-query-build
[[ ! -e $work ]] || { echo 'Use a fresh Actions runner.' >&2; exit 1; }
mkdir -p "$work"/{parent,unpacked,rpmbuild/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS,SRPMS}}
top=$work/rpmbuild
artifact=$owner/build/el2-query-artifact
mkdir -p "$artifact/rpms"
curl -fLsS --retry 2 --connect-timeout 20 --max-time 300 \
    "$(jq -er .parent_srpm_url "$lock")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$lock")" "$work/parent.src.rpm" | sha256sum -c -
rpm2cpio "$work/parent.src.rpm" | (cd "$work/parent"; cpio -idm --quiet --no-absolute-filenames)
cp "$work/parent/"* "$top/SOURCES/"
spec=$top/SPECS/senemos-uke-linux-kernel-mainline-kvm.spec
parent_spec=$work/parent/senemos-uke-linux-kernel-mainline.spec
[[ -f $parent_spec ]]
tar -xJf "$work/parent/senemos-native-profile-7.3.1.tar.xz" -C "$work/unpacked"
tar -xJf "$work/parent/senemos-uke-boot-recipe.tar.xz" -C "$work/unpacked"
profile=$work/unpacked/native-profile
boot=$work/unpacked/boot-recipe
(cd "$profile"; sha256sum --check --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --quiet -)
cp "$profile/SHA256SUMS" "$work/parent-profile.sha256"
cp "$profile/source-composition.json" "$profile/source-composition-before-query.json"

for relative in src/boot/uke-el2-query.h src/boot/prepare-el2-query-source.sh \
    patches/boot/0072-uke-el2-query.patch tests/el2-query-built.sh; do
    install -Dm644 "$owner/$relative" "$profile/$relative"
done
printf '\nbash "$profile/src/boot/prepare-el2-query-source.sh" "$kernel"\n' >> "$profile/prepare.sh"
for config in "$profile/native.config" "$boot/packaging/native/native.config"; do
    sed -i -E '/^(# )?CONFIG_QCOM_UKE_(EL2_QUERY|EL2_ENTRY|GUNYAH_EXIT)(=| is not set)/d' "$config"
    printf '\nCONFIG_QCOM_UKE_EL2_QUERY=y\n' >> "$config"
done
cmp "$profile/native.config" "$boot/packaging/native/native.config"
# The retained normal producer admits a numeric release only. Extend just its
# two ABI guards; keep the build job-count expression and every other line.
while read -r relative line_number; do
    file=$boot/$relative
    old=$(sed -n "${line_number}p" "$file")
    [[ $old == *'[1-9][0-9]*$'* && $old != *'(-kvm)?'* ]]
    new=${old/'[1-9][0-9]*$'/'[1-9][0-9]*(-kvm)?$'}
    UKE_QUERY_OLD_LINE="$old" UKE_QUERY_NEW_LINE="$new" awk '
      $0 == ENVIRON["UKE_QUERY_OLD_LINE"] {$0=ENVIRON["UKE_QUERY_NEW_LINE"]; count++}
      {print}
      END {if(count!=1)exit 1}
    ' "$file" > "$work/abi-guard.sh"
    mv "$work/abi-guard.sh" "$file"
done <<'GUARDS'
src/boot/make-initramfs-base.sh 4
src/boot/build-payload.sh 8
GUARDS
for relative in packaging/native/native.config src/boot/make-initramfs-base.sh src/boot/build-payload.sh; do
    hash=$(sha256sum "$boot/$relative"); hash=${hash%% *}
    jq --arg path "$relative" --arg hash "$hash" \
        '(.source_assets[]|select(.path==$path).sha256)=$hash' \
        "$boot/lock.json" > "$work/boot-lock.json"
    mv "$work/boot-lock.json" "$boot/lock.json"
done
release=7.3.1-2001-kvm jobs=2
eval "$(sed -n '8p' "$boot/src/boot/build-payload.sh")"
(set -- fixture "$release"; eval "$(sed -n '4p' "$boot/src/boot/make-initramfs-base.sh")")
commit=$(git -c safe.directory="$owner" -C "$owner" rev-parse HEAD)
epoch=$(git -c safe.directory="$owner" -C "$owner" show -s --format=%ct HEAD)
release=$(jq -er .kernel_release "$lock")
revision=$(jq -er .rpm_revision "$lock")
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --arg release "$release" \
    --arg parent "$(jq -er .parent_srpm_sha256 "$lock")" \
    '. + {source_mode:"retained1300-el2-query-only",source_commit:$commit,
      parent_copr_build:11251037,parent_srpm_sha256:$parent,
      parent_composition:"source-composition-before-query.json",kernel_release:$release,
      el2_profile:"el2-query-only",firmware_exit_enabled:false,
      automatic_kernel_activation:false,hardware_tested:false}' \
    "$profile/source-composition-before-query.json" > "$profile/source-composition.json"
# Unchanged parent inputs must remain byte-identical; additions are explicit above.
while read -r expected relative; do
    relative=${relative#./}
    case $relative in prepare.sh|native.config|source-commit|source-composition.json) continue;; esac
    printf '%s  %s\n' "$expected" "$profile/$relative" | sha256sum -c --quiet -
done < "$work/parent-profile.sha256"
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
for tree in native-profile boot-recipe; do
    case $tree in
        native-profile) archive=senemos-native-profile-7.3.1.tar.xz;;
        boot-recipe) archive=senemos-uke-boot-recipe.tar.xz;;
    esac
    tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
        -cJf "$top/SOURCES/$archive" -C "$work/unpacked" "$tree"
done
install -m644 "$boot/lock.json" "$top/SOURCES/boot-payload.json"

# Isolate the package ABI and aliases, remove the parent's activation scriptlet,
# and replace normal-family %check assertions with the query candidate checks.
awk -v revision="$revision" '
 /^%description($| boot$| singleboot$)/ {
   print
   print "Experimental Uke SCM INFO service-discovery candidate, query only."
   print "Install matching modules through DNF and flash the selected image manually."
   print "Boot bundles and aliases are isolated from the normal automatic updater."
   print "Build success does not establish device boot or EL2 transfer."
   skip_description=1; next
 }
 skip_description && /^%/ {skip_description=0}
 skip_description {next}
 /^Requires: uke-kernel-update([[:space:](]|$)/ {next}
 /^Requires: uke-installation-profile([[:space:]]|$)/ {next}
 /^%posttrans boot / {skip_script=1; next}
 skip_script && /^%files/ {skip_script=0}
 skip_script {next}
 /^%check$/ {
   print; print "bash native-profile/tests/el2-query-built.sh \"$PWD\" %{_uke_out} %{buildroot} %{krel}"
   skip_checks=1; next
 }
 skip_checks && /^%install$/ {skip_checks=0}
 skip_checks {next}
 /^Name: / {$0="Name: senemos-uke-linux-kernel-mainline-kvm"}
 /^%global senemos_build_release 1300$/ {$0="%global senemos_build_release "revision}
 /^%global krel / {$0="%global krel %{version}-%{senemos_build_release}-kvm"}
 {
   gsub("LOCALVERSION=-%\\{senemos_build_release\\}", "LOCALVERSION=-%{senemos_build_release}-kvm")
   gsub("kernel-updates/", "kvm-kernel-updates/")
   gsub("/usr/lib/senemos/default-boot.img", "/usr/lib/senemos/kvm-default-boot.img")
   gsub("/usr/share/senemos/uke/singleboot.json", "/usr/share/senemos/uke/kvm-singleboot.json")
   gsub("automatic_kernel_activation\": true", "automatic_kernel_activation\": false")
   gsub("KBUILD_BUILD_HOST=copr-builder", "KBUILD_BUILD_HOST=github-actions")
   print
 }
' "$parent_spec" > "$spec"
[[ $(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' "$spec") == 7.3.1-2001 ]]
! rpmspec --parse --target aarch64 "$spec" | grep -E '^%(post|posttrans|pre|pretrans)([[:space:]]|$)'
dnf -y --setopt=install_weak_deps=False builddep "$spec"
cc -std=c11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
    "$owner/tests/el2-query-host.c" -o "$work/el2-query-host"
"$work/el2-query-host"
jobs=$(nproc)
((jobs <= 6)) || jobs=6
rpmbuild -bb --target aarch64 --define "_topdir $top" \
    --define "_smp_build_ncpus $jobs" --define "_smp_mflags -j$jobs" "$spec"

out=$top/native-kernel-out
cp "$top/RPMS/aarch64/"*.rpm "$artifact/rpms/"
for package in "$artifact/rpms/"*.rpm; do
    [[ -z $(rpm -qp --scripts "$package") ]]
    if rpm -qpl "$package" | grep -E '^/usr/lib/senemos/(kernel-updates(/|$)|default-boot[.]img$)'; then
        echo 'Manual candidate overlaps the installed automatic-update trigger.' >&2
        exit 1
    fi
done
install -m644 "$out/userdata.img" "$artifact/boot-userdata.img"
install -m644 "$out/linux.img" "$artifact/boot-linux.img"
install -m644 "$out/.config" "$artifact/kernel.config"
install -m755 "$owner/src/boot/collect-el2-query.sh" "$artifact/collect-el2-query.sh"
install -m644 "$owner/docs/EL2-QUERY-ACTIONS.md" "$artifact/README.md"
install -m644 "$profile/source-composition.json" "$artifact/source-composition.json"
jq --arg source "$commit" --arg run "${GITHUB_RUN_ID:?}" \
    --arg config "$(sha256sum "$out/.config" | cut -d ' ' -f1)" \
    '. + {source_commit:$source,github_run_id:$run,kernel_config_sha256:$config,
      build_completed:true,hardware_tested:false,guest_tested:false}' \
    "$lock" > "$artifact/build-receipt.json"
(cd "$artifact"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf 'Artifact ready: %s; release=%s; firmware_exit_enabled=false\n' "$commit" "$release"
