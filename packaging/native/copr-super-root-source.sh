#!/usr/bin/bash
# COPR source worker only; fetch the exact public full3 source, no compilation.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result" "$work/super-root" "$work/parent"
curl -qfsSL --max-time 600 --max-filesize 209715200 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11333235/senemos-uke-linux-kernel-mainline-unstable-7.3.4-3.src.rpm \
 -o "$work/parent.src.rpm"
printf '%s  %s\n' 8343162259135cbc962ac1a06bd42f062908a684d29e48f53ff7c8bb8bd8c32a "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -i --to-stdout --quiet ./senemos-native-profile-7.3.4.tar.xz | \
 tar -xJf - -C "$work/parent" native-profile/src/boot/uke-root-selector.h native-profile/tests/root-selector-contract.cpp
rpm2cpio "$work/parent.src.rpm" | cpio -i --to-stdout --quiet ./senemos-uke-boot-recipe.tar.xz > "$result/senemos-uke-boot-recipe.tar.xz"
printf '%s  %s\n' c9d89868ba59eb70d042bbb3f70f8c036a3b45004e9f82c2a2accd1bb7cde94d "$work/parent/native-profile/src/boot/uke-root-selector.h" | sha256sum -c --strict --quiet -
install -m644 "$work/parent/native-profile/src/boot/uke-root-selector.h" "$work/super-root/parent-root-selector.h"
install -m644 "$work/parent/native-profile/tests/root-selector-contract.cpp" "$work/super-root/parent-root-selector-test.cpp"
install -m644 "$owner/src/boot/super-root734/uke-super-root-selector.h" "$work/super-root/"
install -m644 "$owner/tests/super-root734.cpp" "$work/super-root/"
install -m644 "$owner/LICENSE" "$work/super-root/"
git -C "$owner" rev-parse HEAD > "$work/super-root/source-commit"
(cd "$work/super-root";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-super-root-source.tar.xz" -C "$work" super-root
install -m644 "$owner/packaging/native/uke-super-root-source-check.spec" "$result/"
install -m644 "$owner/src/boot/super-root734/measure-initrd.sh" "$result/"
git init -q "$work/builder"
git -C "$work/builder" remote add origin https://github.com/MCC45TR/uke-fedora-builder.git
git -C "$work/builder" fetch -q --depth=1 origin 31c893d7e9e7868769513a84eb7f12a62f1d6996
git -C "$work/builder" checkout -q --detach FETCH_HEAD
[[ $(git -C "$work/builder" rev-parse HEAD) == 31c893d7e9e7868769513a84eb7f12a62f1d6996 ]]
mkdir "$work/super-tools"
for script in fastboot-singleboot-layout inspect-fastboot-super plan-super-provision provision-fastboot-super map-fastboot-rescue select-uke-super;do
 install -m644 "$work/builder/src/image/$script.sh" "$work/super-tools/"
done
install -m644 "$work/builder/src/image/dracut/95uke-super-tools/module-setup.sh" "$work/super-tools/"
install -m644 "$work/builder/LICENSE" "$work/super-tools/"
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-super-tools.tar.xz" -C "$work" super-tools
git -C "$work/builder" fetch -q --depth=1 origin 4f64b2085487b0bc6fd261d89989bb88a9f4a222
git -C "$work/builder" checkout -q --detach FETCH_HEAD
[[ $(git -C "$work/builder" rev-parse HEAD) == 4f64b2085487b0bc6fd261d89989bb88a9f4a222 ]]
mkdir "$work/early-super"
for path in src/boot/super-root734/integrate-initrd.sh src/boot/super-root734/apply-boot-profiles.sh \
 src/boot/super-root734/boot-profiles.patch src/boot/super-root734/measure-early-initrd.sh tests/boot-super-profiles734.sh;do
 install -Dm644 "$owner/$path" "$work/early-super/$path"
done
for path in src/image/fastboot-singleboot-layout.sh src/image/inspect-fastboot-super.sh \
 src/image/plan-super-provision.sh src/image/provision-fastboot-super.sh src/image/map-fastboot-rescue.sh \
 src/image/select-uke-super.sh src/image/early-super-policy.sh src/image/prepare-early-super.sh \
 src/image/guard-early-rescue.sh src/image/dracut/95uke-super-tools/module-setup.sh \
 src/image/dracut/96uke-super-boot/module-setup.sh src/image/dracut/96uke-super-boot/uke-super-prepare.service \
 tests/early-super-policy.sh tests/early-super-units.sh LICENSE;do
 install -Dm644 "$work/builder/$path" "$work/early-super/builder/$path"
done
git -C "$work/builder" rev-parse HEAD > "$work/early-super/builder-source-commit"
(cd "$work/early-super";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-super-early-source.tar.xz" -C "$work" early-super
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$result/uke-super-root-source-check.spec") == uke-super-root-source-check-0.1-5.fc46 ]]
printf 'Native rescue parser source check assembled; packaged parent header only, prepared kernel/initrd integration remains unqualified.\n'
