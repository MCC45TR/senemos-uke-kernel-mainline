%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}
%global senemos_build_release 1.4056.1
%global krel %{version}-senemos.%{senemos_build_release}
%global _uke_out %{_topdir}/native-kernel-out

Name: senemos-uke-linux-kernel-mainline
Version: 7.2.10
Release: %{senemos_build_release}%{?dist}
Summary: Mainline Uke kernel with the O82 display profile
License: GPL-2.0-only
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: linux-%{version}.tar.xz
Source1: senemos-uke-adaptation-%{version}.tar.xz
Source2: linux-%{version}.tar.sign
Source3: linux-stable.asc
Source4: senemos-native-profile-%{version}.tar.xz
ExclusiveArch: aarch64
BuildRequires: bash bc bison flex clang llvm lld make gcc gcc-c++ perl
BuildRequires: elfutils-libelf-devel openssl-devel ncurses-devel
BuildRequires: rsync tar xz zstd kmod git-core jq gnupg2 dtc
BuildRequires: python3
Requires: %{name}-core = %{version}-%{release}
Requires: %{name}-modules = %{version}-%{release}
Requires: %{name}-dtbs = %{version}-%{release}

%description
Source-built kernel with the reviewed O82 native display profile.
This source package contains no embedded initramfs, Android boot image,
firmware or device-private data. No boot partition is written. A successful build is not tablet boot
acceptance and does not supply the guarded kernel-update bundle.

%package core
Summary: Uke kernel Image and source identity
Provides: installonlypkg(kernel)
Provides: kernel-uname-r(%{krel})

%description core
Raw Image without an initramfs or boot container. Keep the previously validated
boot bundle until a matching source-built boot producer is physically accepted.

%package modules
Summary: Matching Uke kernel modules
Requires: %{name}-core = %{version}-%{release}
Requires: kmod
Provides: installonlypkg(kernel)

%description modules
Modules from the same native-profile source and configuration as the raw Image.

%package dtbs
Summary: Uke compile-stage device tree and native overlay
Requires: %{name}-core = %{version}-%{release}
Provides: installonlypkg(kernel)

%description dtbs
Independent compile-stage DTB and exact O82-42 native display overlay. Physical
boot requires the separately validated dynamic stock-bootloader handoff.

%prep
expected=$(tar -xOJf %{SOURCE1} senemos-adaptation/source-lock.json | jq -er .source_sha256)
test "$(sha256sum %{SOURCE0} | cut -d ' ' -f1)" = "$expected"
signer=$(tar -xOJf %{SOURCE1} senemos-adaptation/source-lock.json | jq -er .signer)
# GnuPG agent sockets cannot use arbitrarily long RPM build paths.
keyring=$(mktemp -d)
trap 'gpgconf --homedir "$keyring" --kill gpg-agent; rm -rf "$keyring"' EXIT
gpg --homedir "$keyring" --batch --import %{SOURCE3}
xz -cd %{SOURCE0} | gpg --homedir "$keyring" --batch --status-fd=1 \
    --verify %{SOURCE2} - > %{_topdir}/source-verification.txt
grep -F "[GNUPG:] VALIDSIG $signer " %{_topdir}/source-verification.txt
%setup -q -n linux-%{version}
tar -xJf %{SOURCE1}
jq -r '.patches[].path | split("/") | last' senemos-adaptation/source-lock.json > senemos-expected-patches.txt
cmp senemos-expected-patches.txt senemos-adaptation/patches/series
while IFS="$(printf '\t')" read -r path expected; do
    case "$path" in
        patches/*) staged="senemos-adaptation/patches/${path##*/}" ;;
        configs/*) staged="senemos-adaptation/configs/${path##*/}" ;;
        *) exit 1 ;;
    esac
    test "$(sha256sum "$staged" | cut -d ' ' -f1)" = "$expected" || exit 1
done <<EOF
$(jq -r '.patches[], .configs[] | [.path,.sha256] | @tsv' senemos-adaptation/source-lock.json)
EOF
# Keep git apply rooted here even when the RPM development tree is nested
# inside a workspace repository. Otherwise Git silently skips those paths.
git -c init.defaultBranch=senemos init -q
: > senemos-applied-patches.txt
while IFS= read -r patch_name; do
    test -n "$patch_name" || continue
    git apply --check "senemos-adaptation/patches/$patch_name" || exit 1
    git apply "senemos-adaptation/patches/$patch_name" || exit 1
    printf '%s\n' "$patch_name" >> senemos-applied-patches.txt
done < senemos-adaptation/patches/series
cmp senemos-expected-patches.txt senemos-applied-patches.txt

tar -xJf %{SOURCE4}
bash native-profile/prepare.sh "$PWD"

%build
export ARCH=arm64 LLVM=1 LLVM_IAS=1
export KBUILD_BUILD_USER=senemos KBUILD_BUILD_HOST=copr-builder KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1791725270
export KBUILD_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH" '+%%Y-%%m-%%d %%H:%%M:%%S UTC')"
mkdir -p %{_uke_out}
install -m644 native-profile/native.config %{_uke_out}/.config
scripts/config --file %{_uke_out}/.config --set-str INITRAMFS_SOURCE ''
make O=%{_uke_out} LOCALVERSION=-senemos.%{senemos_build_release} olddefconfig
grep -Fx 'CONFIG_INITRAMFS_SOURCE=""' %{_uke_out}/.config
for requirement in CONFIG_QCOM_UKE_ABL_DT=y CONFIG_DRM_MSM=m \
    CONFIG_DRM_PANEL_XIAOMI_O82=m CONFIG_SM_DISPCC_8250=y \
    CONFIG_DRM_FBDEV_EMULATION=y CONFIG_BACKLIGHT_KTZ8866=m; do
    grep -Fx "$requirement" %{_uke_out}/.config
done
jobs=%{?_smp_build_ncpus}%{!?_smp_build_ncpus:4}
test "$jobs" -le 8 || jobs=8
make O=%{_uke_out} LOCALVERSION=-senemos.%{senemos_build_release} -j"$jobs" Image modules dtbs
test "$(make -s O=%{_uke_out} LOCALVERSION=-senemos.%{senemos_build_release} kernelrelease)" = '%{krel}'

%check
CC=clang bash native-profile/tests/o82-mode-contract.sh native-profile/src/display/o82-mode.h native-profile/src/display/o82-data.h
CXX=clang++ bash native-profile/tests/o82-mode-valid-contract.sh drivers/gpu/drm/msm/dsi/dsi_manager.c native-profile/src/display/o82-mode.h native-profile/src/display/o82-data.h
CC=clang bash native-profile/tests/o82-panel-contract.sh native-profile/src/display/panel-xiaomi-o82.c native-profile/src/display/o82-data.h "$PWD"
CC=clang bash native-profile/tests/o82-readback-contract.sh "$PWD"
CXX=clang++ bash native-profile/tests/o82-refresh-host-contract.sh drivers/gpu/drm/msm/dsi/dsi_host.c native-profile/src/display/o82-mode.h native-profile/src/display/o82-data.h
CXX=clang++ bash native-profile/tests/o82-pll-bias-contract.sh "$PWD" %{_uke_out}
CXX=clang++ bash native-profile/tests/dpu-dsi-timing-contract.sh drivers/gpu/drm/msm/disp/dpu1/dpu_encoder_phys_vid.c drivers/gpu/drm/msm/dsi/dsi_host.c native-profile/src/display/o82-data.h native-profile/src/display/panel-xiaomi-o82.c

CXX=clang++ bash native-profile/tests/o82-dfps-host-contract.sh drivers/gpu/drm/msm/dsi/dsi_host.c native-profile/src/display/o82-mode.h native-profile/src/display/o82-data.h
CC=clang bash native-profile/tests/o82-dfps-atomic-contract.sh drivers/gpu/drm/msm/msm_atomic.c
CC=clang bash native-profile/tests/o82-dfps-lifetime-contract.sh drivers/gpu/drm/msm/msm_atomic.c drivers/gpu/drm/msm/dsi/dsi_manager.c
CC=clang bash native-profile/tests/o82-dfps-panel-contract.sh native-profile/src/display/panel-xiaomi-o82.c native-profile/src/display/o82-data.h native-profile/src/display/o82-mode.h native-profile/src/display/qcom-uke-display.h
CC=clang bash native-profile/tests/dsi-read-transaction-contract.sh "$PWD" %{_uke_out}

%install
export ARCH=arm64 LLVM=1
make O=%{_uke_out} LOCALVERSION=-senemos.%{senemos_build_release} modules_install INSTALL_MOD_PATH=%{buildroot} INSTALL_MOD_STRIP=1 DEPMOD=true
mkdir -p %{buildroot}/usr/lib/modules
mv %{buildroot}/lib/modules/%{krel} %{buildroot}/usr/lib/modules/
rm -rf %{buildroot}/lib
module_dir=%{buildroot}/usr/lib/modules/%{krel}
rm -f "$module_dir/build" "$module_dir/source"
find "$module_dir" -type f -name '*.ko' -exec zstd -q -T1 --rm {} \;
install -m644 %{_uke_out}/arch/arm64/boot/Image "$module_dir/vmlinuz"
install -m644 %{_uke_out}/.config "$module_dir/config"
install -m644 %{_uke_out}/System.map "$module_dir/System.map"
mkdir -p "$module_dir/dtb/qcom" "$module_dir/dtb/overlays"
install -m644 %{_uke_out}/arch/arm64/boot/dts/qcom/sm7675-xiaomi-uke.dtb "$module_dir/dtb/qcom/"
install -m644 native-generated/display.dtbo "$module_dir/dtb/overlays/uke-o82-oem-modes.dtbo"
depmod -b %{buildroot} -m /usr/lib/modules -a %{krel}
identity=%{buildroot}/usr/share/senemos/uke/%{krel}
mkdir -p "$identity"
install -m644 native-profile/SHA256SUMS native-profile/source-commit native-profile/README.md "$identity/"
install -m644 senemos-adaptation/source-lock.json senemos-applied-patches.txt "$identity/"
test -z "$(find %{buildroot} -type f \( -name '*.py' -o -name '*.pyc' -o -name 'python*' \) -print -quit)"

%files
%doc native-profile/README.md
%license COPYING

%files core
%dir /usr/lib/modules/%{krel}
/usr/lib/modules/%{krel}/vmlinuz
/usr/lib/modules/%{krel}/config
/usr/lib/modules/%{krel}/System.map
/usr/lib/modules/%{krel}/modules.builtin*
/usr/lib/modules/%{krel}/modules.order
/usr/share/senemos/uke/%{krel}/

%files modules
/usr/lib/modules/%{krel}/kernel/
/usr/lib/modules/%{krel}/modules.alias*
/usr/lib/modules/%{krel}/modules.dep*
/usr/lib/modules/%{krel}/modules.devname
/usr/lib/modules/%{krel}/modules.softdep
/usr/lib/modules/%{krel}/modules.symbols*
/usr/lib/modules/%{krel}/modules.weakdep

%files dtbs
/usr/lib/modules/%{krel}/dtb/

%changelog
* Sat Oct 17 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.10-1.4056.1
- Enable standard Bluetooth LE HID input and RFCOMM facilities.
- Use the Uke UART speed that completes stock QCA firmware transfer.

* Sat Oct 17 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.4054.3
- Consolidate the complete O82 source profile under the mainline package name.
- Give each numeric build its own module ABI and preserve installed fallback kernels.
- Keep boot writes unavailable until the public boot producer is accepted.

* Sat Oct 17 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-2
- Build the native54 live-refresh source and all seven-mode contract checks.
- Retain the compile-only boundary without a flashable boot container.

* Sat Oct 17 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1
- Build the complete native O82 source profile in an isolated kernel namespace.
- Keep private initramfs and unreproducible boot containers out of COPR.
