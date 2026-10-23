%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}
%global _uke_out %{_topdir}/native-kernel-out
%global uke_boot_userspace %{_topdir}/boot-userspace

Name: senemos-uke-linux-kernel-mainline-unstable
Version: 7.3.0
%if "%{version}" == "7.3.0"
%global senemos_build_release 11
%else
%global senemos_build_release 1
%endif
%global krel %{version}-%{senemos_build_release}-unstable
Release: %{senemos_build_release}%{?dist}
Summary: Unstable Linux 7.3 Uke kernel with the O82 display profile
License: GPL-2.0-only AND MIT
SourceLicense: GPL-2.0-only AND MIT AND GPL-3.0-or-later AND Apache-2.0
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: linux-%{version}.tar.xz
Source1: senemos-uke-adaptation-%{version}.tar.xz
Source2: linux-%{version}.tar.sign
Source3: linux-stable.asc
Source4: senemos-native-profile-%{version}.tar.xz
Source5: senemos-uke-boot-recipe.tar.xz
Source6: boot-payload.json
Source7: SINGLEBOOT.md
Source8: singleboot-LICENSE
Source9: senemos-uke-touch-runtime-1.tar.xz
ExclusiveArch: aarch64
BuildRequires: bash bc bison flex clang llvm lld make gcc gcc-c++ perl
BuildRequires: compiler-rt
BuildRequires: elfutils-libelf-devel openssl-devel ncurses-devel
BuildRequires: pkgconfig(libsystemd)
BuildRequires: alsa-topology-utils
BuildRequires: rsync tar xz zstd kmod git-core jq gnupg2 dtc
BuildRequires: python3
BuildRequires: dracut systemd systemd-udev util-linux coreutils grep sed findutils binutils ripgrep gzip cpio f2fs-tools
Requires: %{name}-core = %{version}-%{release}
Requires: %{name}-modules = %{version}-%{release}
Requires: %{name}-dtbs = %{version}-%{release}
Requires: %{name}-boot = %{version}-%{release}

%description
Source-built kernel with the reviewed O82 native display profile.
The boot subpackage contains a source-built initramfs and Android v4 container
with matching modules. It contains no OEM firmware or device-private data.
No package script activates a kernel or changes a slot. Build success does
not establish physical tablet acceptance.

%package core
Summary: Uke kernel Image and source identity
Provides: installonlypkg(kernel)
Provides: kernel-uname-r(%{krel})
Provides: uke-kernel(platform-profile-qos-v1) = 1

%description core
Image with the matching source-built initramfs, configuration and source record.

%package modules
Summary: Matching Uke kernel modules
License: GPL-2.0-only AND GPL-3.0-or-later AND MIT AND Apache-2.0
Requires: %{name}-core = %{version}-%{release}
Requires: kmod
Provides: installonlypkg(kernel)

%description modules
Modules from the same native-profile source and configuration as the raw Image.
The separately licensed calibrated touch processor is matched to this release.

%package dtbs
Summary: Uke compile-stage device tree and native overlay
Requires: %{name}-core = %{version}-%{release}
Provides: installonlypkg(kernel)

%description dtbs
Independent compile-stage DTB and exact O82-42 native display overlay. Physical
boot requires the separately validated dynamic stock-bootloader handoff.

%package boot
Summary: Matched native-display boot bundle for Uke
Requires: %{name}-core = %{version}-%{release}
Requires: %{name}-modules = %{version}-%{release}
Requires: %{name}-dtbs = %{version}-%{release}
Requires: uke-kernel-update >= 1.3.1
Requires: uke-kernel-update(guarded-automatic) >= 1
Requires: uke-kernel-update(kernel-touch-client-v1) >= 1
Requires: uke-boot-integration(kernel-touch-dispatch-v1) >= 1
Requires: (uke-power-profile-backend(native-handoff-v1) >= 1 if uke-power-profile-backend)
Provides: installonlypkg(kernel)

%description boot
Kernel-only Android v4 image for boot_b and PARTLABEL=linux. The native updater
checks package identities, module digests, physical storage and power, preserves
the previous image, and verifies write readback. Android A is not an update target.

%package singleboot
Summary: Matched Uke userdata boot profile
License: MIT
Requires: %{name} = %{version}-%{release}
Requires: uke-installation-profile >= 1.3.1
Requires: uke-kernel-update(root-filesystem-v2) >= 1

%description singleboot
Selects the userdata image from this source family's exact kernel tuple.
Image, modules, DTBs and both root profiles are built once. Installation
performs no boot activation, partition write, slot selection or reboot.

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
%setup -q -n linux-7.3
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
tar -xJf %{SOURCE5}
cmp boot-recipe/lock.json %{SOURCE6}
(cd boot-recipe; jq -r '.source_assets[] | .sha256 + "  " + .path' lock.json | sha256sum -c -)
tar -xJf %{SOURCE9}
(cd touch-runtime; sha256sum --check --strict SOURCE-SHA256SUMS)

%build
export ARCH=arm64 LLVM=1 LLVM_IAS=1
export KBUILD_BUILD_USER=senemos KBUILD_BUILD_HOST=copr-builder KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1791725270
export KBUILD_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH" '+%%Y-%%m-%%d %%H:%%M:%%S UTC')"
mkdir -p %{_uke_out}
if test ! -e %{uke_boot_userspace}; then
    bash boot-recipe/src/boot/make-initramfs-base.sh %{uke_boot_userspace} '%{krel}'
fi
test "$(cat %{uke_boot_userspace}/kernel-release)" = '%{krel}'
(cd %{uke_boot_userspace}; sha256sum -c base-files.sha256)
jobs=%{?_smp_build_ncpus}%{!?_smp_build_ncpus:4}
test "$jobs" -le 8 || jobs=8
g++ %{build_cxxflags} -std=c++20 -Wall -Wextra -Werror -ffile-prefix-map=$PWD=. \
    touch-runtime/capture/touch-capture.cpp touch-runtime/capture/upstream/nt36532-thp/nvt_touch_core.cpp \
    -lcrypto -lsystemd -o native-generated/uke-touch-capture %{build_ldflags}
readelf -h native-generated/uke-touch-capture | grep -E 'Machine:.*AArch64'
bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base '%{krel}' "$jobs"
for requirement in CONFIG_QCOM_UKE_ABL_DT=y CONFIG_PSI=y CONFIG_DRM_MSM=m \
    CONFIG_DRM_PANEL_XIAOMI_O82=m CONFIG_SM_DISPCC_8550=m \
    CONFIG_DRM_FBDEV_EMULATION=y CONFIG_BACKLIGHT_KTZ8866=m \
    CONFIG_EXT4_FS=y CONFIG_F2FS_FS=y CONFIG_XFS_FS=y CONFIG_BTRFS_FS=y \
    CONFIG_QCOM_UKE_PLATFORM_PROFILE=y CONFIG_ACPI_PLATFORM_PROFILE=y \
    CONFIG_SND_SEQUENCER=m; do
    grep -Fx "$requirement" %{_uke_out}/.config
done
grep -Fx '# CONFIG_PSI_DEFAULT_DISABLED is not set' %{_uke_out}/.config
test "$(make -s O=%{_uke_out} LOCALVERSION=-%{senemos_build_release}-unstable kernelrelease)" = '%{krel}'

%check
bash native-profile/tests/unstable-upstream-contract.sh "$PWD"
bash native-profile/tests/touch-runtime-package-contract.sh
grep -Fx 'CONFIG_VIDEO_NT36532_UKE_THP=m' %{_uke_out}/.config
test -s %{_uke_out}/boot-modules/lib/modules/%{krel}/kernel/drivers/media/spi/nt36532-uke/nt36532-uke-thp.ko.zst
modinfo -F alias %{_uke_out}/boot-modules/lib/modules/%{krel}/kernel/drivers/media/spi/nt36532-uke/nt36532-uke-thp.ko.zst | grep -Fx 'spi:nt36532-uke-thp'
CC=clang bash native-profile/tests/spi-geni-completion-contract.sh drivers/spi/spi-geni-qcom.c
test -x %{buildroot}/usr/lib/modules/%{krel}/uke/uke-touch-capture
test "$(sha256sum %{buildroot}/usr/lib/modules/%{krel}/uke/uke-touch-capture | cut -d ' ' -f1)" = "$(sed -n 's/^touch_client_sha256=//p' %{_uke_out}/boot-manifest)"
CC=clang bash native-profile/tests/resin-wake-contract.sh "$PWD"
bash boot-recipe/tests/early-modules-contract.sh
CC=clang bash native-profile/tests/platform-profile-contract.sh
CC=clang bash native-profile/tests/platform-profile-framework-contract.sh "$PWD"
bash native-profile/tests/identity-contract.sh
test "$(readlink %{buildroot}/usr/lib/senemos/unstable-default-boot.img)" = kernel-updates/%{krel}/userdata.img
jq -e '.kernel_release=="%{krel}" and .automatic_kernel_activation==false' %{buildroot}/usr/share/senemos/uke/unstable-singleboot.json
bash native-profile/tests/native-firewall-contract.sh %{_uke_out}/.config %{_uke_out}
CC=clang bash native-profile/tests/llcc-sm7675-contract.sh "$PWD"
CC=clang bash native-profile/tests/llcc-gpu-startup-contract.sh drivers/gpu/drm/msm/adreno/adreno_device.c
CC=clang bash native-profile/tests/llcc-boot-fdt-contract.sh "$PWD"
test "$(cat native-generated/llcc-profile)" = native-v1
grep -Fx '#define UKE_LLCC_NATIVE_PROFILE 1' arch/arm64/kernel/uke-llcc-profile.h
CXX=clang++ bash native-profile/tests/uke-rpmh-resource-contract.sh native-generated/rpmh-regulator-before-native.c pre-native
CXX=clang++ bash native-profile/tests/uke-rpmh-resource-contract.sh drivers/regulator/qcom-rpmh-regulator-uke.c native
CXX=clang++ bash native-profile/tests/ktz-dimming-observation-contract.sh drivers/video/backlight/ktz8866.c
bash boot-recipe/tests/boot-image-contract.sh %{_uke_out}/boot-image
CXX=clang++ bash native-profile/tests/root-selector-contract.sh
CC=clang bash native-profile/tests/root-selector-note-contract.sh "$PWD" "$PWD/boot-recipe/lock.json"
bash boot-recipe/tests/target-privacy-contract.sh
CC=clang bash native-profile/tests/battery-protocol-contract.sh "$PWD"
CC=clang bash native-profile/tests/qrtr-handshake-contract.sh "$PWD"
CC=clang bash native-profile/tests/battery-coordinator-contract.sh "$PWD"
CC=clang bash native-profile/tests/battery-control-transport.sh "$PWD"
CC=clang bash native-profile/tests/battery-control-guard-contract.sh "$PWD"
CC=clang bash native-profile/tests/battery-protection-contract.sh "$PWD"
CC=clang bash native-profile/tests/battery-settings-contract.sh "$PWD"
CC=clang bash native-profile/tests/battery-preconfigured-cap-contract.sh "$PWD"
CC=clang bash native-profile/tests/battery-preconfigured-apply-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-gpr-bounds-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-prm-response-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-unmap-response-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-graph-response-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-port-lifetime-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-rx-queue-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-compress-lock-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-buffer-submit-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-graph-lifetime-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-service-lifetime-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-service-add-contract.sh "$PWD"
CC=clang bash native-profile/tests/audio-readiness-contract.sh "$PWD"
CXX=clang++ bash native-profile/tests/audio-preset-contract.sh
CXX=clang++ bash native-profile/tests/audio-acdb-contract.sh
CC=clang bash native-profile/tests/audio-card-contract.sh "$PWD"
test -s %{_uke_out}/sound/core/seq/snd-seq.ko
bash native-profile/tests/audio-services-fdt-contract.sh
CXX=clang++ bash native-profile/tests/offline-boot-contract.sh
bash native-profile/tests/serial-power-budget-contract.sh "$PWD"
bash native-profile/tests/usb-charger-readiness-contract.sh "$PWD"
CC=clang bash native-profile/tests/usb-qmp-tables.sh "$PWD"
CC=clang bash native-profile/tests/usb-utmi-resume-contract.sh "$PWD"
CC=clang bash native-profile/tests/usb-role-observation-contract.sh "$PWD"
CXX=clang++ bash native-profile/tests/ucsi-notification-contract.sh drivers/usb/typec/ucsi/ucsi_glink.c
CC=clang bash native-profile/tests/ucsi-transport-contract.sh drivers/usb/typec/ucsi/ucsi_glink.c
CXX=clang++ bash native-profile/tests/altmode-notification-contract.sh drivers/soc/qcom/pmic_glink_altmode.c
for symbol in FW_LOADER_COMPRESS FW_LOADER_COMPRESS_XZ FW_LOADER_COMPRESS_ZSTD; do
    grep -Fx "CONFIG_$symbol=y" %{_uke_out}/.config
done
CC=clang CXX=clang++ bash native-profile/tests/pmic-adc-contract.sh "$PWD"
CC=clang bash native-profile/tests/adc5-gen3-units.sh "$PWD"
CC=clang bash native-profile/tests/adc5-gen3-scalers.sh "$PWD"
CC=clang CXX=clang++ bash native-profile/tests/hall-contract.sh "$PWD"
CC=clang bash native-profile/tests/smp2p-restart-contract.sh "$PWD"
CC=clang bash native-profile/tests/cpucp-mailbox-contract.sh "$PWD"
CC=clang bash native-profile/tests/scmi-discovery-contract.sh "$PWD"
CC=clang bash native-profile/tests/empty-oem-nodes-contract.sh "$PWD"
CC=clang bash native-profile/tests/bluetooth-fdt-contract.sh "$PWD"
CC=clang bash native-profile/tests/wlan-remove-contract.sh "$PWD"
CC=clang bash native-profile/tests/bluetooth-power-contract.sh drivers/bluetooth/hci_qca.c
grep -Fx 'CONFIG_BT_LE=y' %{_uke_out}/.config
grep -Fx 'CONFIG_BT_BNEP=m' %{_uke_out}/.config
test -s %{_uke_out}/net/bluetooth/bnep/bnep.ko
CC=clang bash native-profile/tests/lucid-reset-rate-contract.sh "$PWD"
CC=clang bash native-profile/tests/o82-avr-contract.sh "$PWD"
CC=clang bash native-profile/tests/o82-avr-retime-contract.sh drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c
CC=clang bash native-profile/tests/o82-vrr-capability-contract.sh "$PWD"
CC=clang bash native-profile/tests/dpu-watchdog-lifecycle-contract.sh "$PWD"
CXX=clang++ bash native-profile/tests/dsi-panel-sequence-contract.sh drivers/gpu/drm/msm/dsi/dsi_manager.c
CXX=clang++ bash native-profile/tests/dp-connector-state-contract.sh drivers/gpu/drm/msm/dp/dp_drm.c
CXX=clang++ bash native-profile/tests/dsi-color-depth-contract.sh drivers/gpu/drm/msm/dsi/dsi_manager.c
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
install -Dm644 %{SOURCE7} %{buildroot}%{_docdir}/%{name}-singleboot/SINGLEBOOT.md
install -Dm644 %{SOURCE8} %{buildroot}%{_licensedir}/%{name}-singleboot/LICENSE
install -d %{buildroot}/usr/share/senemos/uke %{buildroot}/usr/lib/senemos
cat > %{buildroot}/usr/share/senemos/uke/unstable-singleboot.json <<'EOF'
{
  "schema_version": 1,
  "package": "%{name}-singleboot",
  "kernel_release": "%{krel}",
  "root_partition": "userdata",
  "root_filesystem": "f2fs",
  "boot_selector": "senemos.root=userdata",
  "boot_image": "/usr/lib/senemos/kernel-updates/%{krel}/userdata.img",
  "automatic_kernel_activation": false
}
EOF
ln -s kernel-updates/%{krel}/userdata.img %{buildroot}/usr/lib/senemos/unstable-default-boot.img
export ARCH=arm64 LLVM=1
mkdir -p %{buildroot}/usr/lib/modules
cp -a %{_uke_out}/boot-modules/lib/modules/%{krel} %{buildroot}/usr/lib/modules/
module_dir=%{buildroot}/usr/lib/modules/%{krel}
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
install -Dm644 native-generated/POCO-Pad-X1-AudioReach-tplg.bin \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/sm7675/POCO-Pad-X1-AudioReach-tplg.bin
test -z "$(find %{buildroot} -type f \( -name '*.py' -o -name '*.pyc' -o -name 'python*' \) -print -quit)"
bundle=%{buildroot}/usr/lib/senemos/kernel-updates/%{krel}
mkdir -p "$bundle"
install -m644 %{_uke_out}/linux.img "$bundle/linux.img"
install -m644 %{_uke_out}/userdata.img "$bundle/userdata.img"
install -m644 %{_uke_out}/modules.sha256 "$bundle/modules.sha256"
install -m644 %{_uke_out}/boot-manifest "$bundle/manifest"
install -m644 %{SOURCE6} "$bundle/source-lock.json"
install -m644 %{uke_boot_userspace}/build-rpms.tsv "$bundle/build-rpms.tsv"
mkdir -p %{buildroot}/usr/share/licenses/%{name}-boot-%{version}-%{release}
cp -a %{uke_boot_userspace}/licenses/. %{buildroot}/usr/share/licenses/%{name}-boot-%{version}-%{release}/
cp -a boot-recipe/src/boot/licenses/. %{buildroot}/usr/share/licenses/%{name}-boot-%{version}-%{release}/

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
/usr/lib/firmware/%{krel}/

%files modules
%license touch-runtime/capture/LICENSE.GPL-3.0 touch-runtime/capture/LICENSE.MIT touch-runtime/capture/upstream/nt36532-thp/LICENSE
/usr/lib/modules/%{krel}/uke/
/usr/lib/modules/%{krel}/kernel/
/usr/lib/modules/%{krel}/modules.alias*
/usr/lib/modules/%{krel}/modules.dep*
/usr/lib/modules/%{krel}/modules.devname
/usr/lib/modules/%{krel}/modules.softdep
/usr/lib/modules/%{krel}/modules.symbols*
/usr/lib/modules/%{krel}/modules.weakdep

%files dtbs
/usr/lib/modules/%{krel}/dtb/

%files boot
/usr/lib/senemos/kernel-updates/%{krel}/
%license /usr/share/licenses/%{name}-boot-%{version}-%{release}/

%files singleboot
%doc %{_docdir}/%{name}-singleboot/SINGLEBOOT.md
%license %{_licensedir}/%{name}-singleboot/LICENSE
/usr/share/senemos/uke/unstable-singleboot.json
/usr/lib/senemos/unstable-default-boot.img

%changelog
* Sat Oct 24 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-11
- Avoid blocking optional SMMU fault capture behind GPU recovery's mutex.
- Check actual capture and fault-completion lock-cycle behavior before building.
- Preserve the existing unstable profile and device policies.

* Fri Oct 23 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-9
- Export the native touchscreen SPI alias for standard module autoload.
- Preserve SPI-core byte accounting after successful GENI GPI DMA transfers.
- Check the built alias and actual DMA callback success and failure paths.

* Fri Oct 23 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-8
- Scope fixed-board drivers and DTB compilation to Uke with explicit clock suppliers.
- Retain the family boot, touch, QRTR and singleboot contracts with early dependency validation.
* Fri Oct 23 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-7
- Carry the matched touch runtime and transport-ready QRTR handshake from mainline19.
- Retain Linux 7.3 compatibility changes and the registration-only audio baseline.
- Preserve the unstable ABI and absence of activation scriptlets.

* Fri Oct 23 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-18
- Pair the Uke SPI/IRQ capture driver and DT with its calibrated C++ processor.
- Validate the versioned processor digest with the matching module RPM.
- Invalidate completed touch buffers before system suspend.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-14
- Omit IOMMU attachment for the closed AudioReach registration profile.
- Supply the sequencer module required by the original Fedora ALSA load rule.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-13
- Skip PCM construction and teardown mappings in the registration-only profile.
- Check all four PCM/compressed lifecycle entry guards before packaging.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-12
- Register the Uke AudioReach card and frontends with PCM opens denied.
- Preserve disabled physical audio paths and version the frontend topology.
- Require the Fedora topology compiler subpackage on the build worker.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-11
- Expose the standard volume-down wake permission on the exact Uke PMIC node.
- Preserve the accepted audio-service, display and native profile source inputs.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-10
- Register native APM and PRM services while keeping physical audio paths disabled.
- Unwind failed router service publication before releasing the device.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-9
- Add a guarded native Uke CPU/GPU platform-profile QoS provider.
- Retain the standard legacy profile ABI on DT without enabling ACPI tables.
- Preserve hardware frequency tables, independent thermal limits and error rollback.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-8
- Admit required early drivers only from installed modules or the exact built-in inventory.
- Require the current-slot transaction consumer before manual userdata updates.

* Thu Oct 22 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-7
- Admit explicit F2FS, EXT4, XFS and single-device Btrfs userdata filesystems.
- Declare root-selector ABI v2 and retain F2FS-only offline growth.

* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-6
- Complete offline userdata expansion without post-root battery RPC dependencies.
- Keep the completed initrd check active and skip repeated filesystem tools.
- Report the Uke SM7675 SoC name without changing native CPU core identities.

* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-5
- Expand the provisioned F2FS userdata filesystem offline before mounting root.
- Preserve filesystem identity, the partition table and the selected-root guard.

* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-4
- Report the fixed O82 10-bpc transport through the standard connector property.
- Check connector state allocation, error propagation and foreign-panel exclusion.

* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-3
- Build singleboot metadata in the kernel family with exact matching dependencies.
- Identify the observed POCO SKU through the live OF model before userspace.

* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.12-1
- Carry the 98-patch Uke profile to signed Linux 7.2.12.
- Preserve matched boot payloads, guarded updates and separate device acceptance.

* Wed Oct 21 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-17
- Retain a versioned Image capability and require the guarded updater.
- Confirm the independent OEM SDP adapter before USB budget writes.
- Use the current per-CPU workqueue API without changing budget semantics.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-16
- Restore the kernel primitives required by the original nftables firewall backend.
- Select one root filesystem type and a bounded userdata panic restart policy.
- Exclude conflicting root policy from embedded dracut defaults.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-15
- Select the matched Cliffs7 cache source profile and defer GPU probe until its supplier binds.
- Forward exact slot identity and private userdata VRR arguments through the forced command line.
- Preserve the existing root profiles, charging policy and disabled audio profile.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-12
- Bound APM basic replies and propagate readiness and PRM firmware errors
- Preserve APM unmap status and separate data/position buffer handles
- Correlate PRM replies with one pending token, opcode and parameter
- Bound graph events, DMA response payloads and period indices
- Drain dynamic GPR callbacks before port and graph state release
- Detach APR receive batches under the IRQ-safe queue lock
- Use a sleepable lock around compressed stream command submission
- Preserve 128 KiB token lengths and validate fragment submissions
- Reject failed or mismatched DMA completions without false progress
- Qualify graph OPEN, quarantine failed IDs and guard graph references
- Quiesce native audio services before topology and driver-data teardown
- Keep audio disabled; add actual-source response regression fixtures

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-11
- Expose cached UCSI GLINK request results, service epochs and event timestamps.
- Validate error/refusal bookkeeping without changing transport or routing policy.

* Tue Oct 20 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-10
- Gate Uke charging on qualified moisture, thermal and periodic fault checks.
- Add fixed owned input suspension and preserve unqualified physical status.

* Mon Oct 19 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-9
- Assert SCMI transfer allocation counts in the Clang package check.

* Mon Oct 19 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-8
- Validate the fixed SCMI list header before reading its count, including empty lists.

* Mon Oct 19 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-7
- Expose error-qualified cached SCMI protocol discovery without new firmware requests.
- Reject incomplete lists in diagnostic results and retain existing consumer behavior.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-29
- Add an explicit root-only, read-only firmware threshold query without control admission.
- Bound diagnostic GETs and reject active leases, lifecycle changes and partial results.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-27
- Accept observed UCSI type-2 notifications with opcode-specific validation.
- Exercise the actual callback's reply, notification and lifecycle boundaries.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-22
- Retain exact O82 live timing updates while AVR remains enabled.
- Update both AVR periods before their common timing flush without panel reset.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-21
- Register the single battery diagnostic group with the supported managed API.
- Remove unused getter snapshots while retaining coordinated generation checks.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-16
- Remove an unused legacy VA scalar flag that OF misinterprets as a GPIO provider.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-15
- Translate the Uke UART wake IRQ to the falling-edge trigger used by its OEM driver.
- Enable standard Bluetooth LE and BNEP support required by desktop Bluetooth services.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-14
- Stop O82 DSI video after both DPU timing engines and preserve panel OFF clocks.
- Preserve the five-frame watchdog budget at the experimental AVR floor.
- Correct the captured secondary SPMI resource address and vblank trace refcount.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-13
- Align host FDT fixtures to libfdt's eight-byte buffer contract on AArch64.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-12
- Latch EVO/OLE PLL settings on reset exit without waiting for an unavailable ACK.
- Preserve live PLL checks and propagate register-access failures.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-11
- Disable the exact empty secondary SPMI bus and zero-length OEM demura placeholders.
- Preserve populated controllers, nonzero reservations and all phandles.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-7
- Map OEM paired hall events to standard input switches without physical GPIO ownership.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-6
- Admit OEM charger and battery ADC conversions with standard current and temperature units.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-5
- Preserve SMP2P input history until a real remote restart.
- Test ordinary updates and both restart flag transitions.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-4
- Exclude PAS from the early module list until root firmware is available.

* Sun Oct 18 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-3
- Expose admitted PMIC voltage and temperature channels through standard Linux interfaces.
- Correct ADC5 Gen3 voltage types and processed units.

* Sat Oct 17 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-2
- Restore the source-built native boot bundle with versioned matching modules.
- Use integer releases and expose signed battery power from voltage/current.

* Sat Oct 17 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.11-1.4056.1
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
