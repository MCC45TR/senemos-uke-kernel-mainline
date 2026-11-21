%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}
%global _uke_out %{_topdir}/native-kernel-out
%global uke_boot_userspace %{_topdir}/boot-userspace

Name: senemos-uke-linux-kernel-mainline
Requires: uke-kernel-update >= 1.8.101
Requires: uke-kernel-update(alternating-checkpoint-v2) >= 1
Provides: uke-kernel(cdsp-pogo-candidate-v1) = 1
Version: 7.3.5
%if "%{version}" == "7.3.4"
%global senemos_build_release 13
%else
%global senemos_build_release 13
%endif
%global source_krel %{version}-%{senemos_build_release}-unstable
%global normal_rpm_release 36
%global normal_parent_copr 11370334
%global krel %{version}-%{normal_rpm_release}
%global uke_audio_driver %(printf 'uke%%s' '%{version}-%{senemos_build_release}u' | tr '.' '_')
Release: %{normal_rpm_release}%{?dist}
Summary: Mainline Linux 7.3.5 Uke kernel with O82 display and Cliffs video
License: GPL-2.0-only AND MIT AND BSD-3-Clause
SourceLicense: GPL-2.0-only AND MIT AND BSD-3-Clause AND GPL-3.0-or-later AND Apache-2.0 AND LGPL-2.0-or-later
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
Source190: uke-native-hardware-delivery.tar.xz
Source191: uke-ssc-time-reference-delivery.tar.xz
Source192: uke-hwkm-early.tar.xz
Source193: uke-qtee-information.tar.xz
Source200: uke-crm-passive.tar.xz
ExclusiveArch: aarch64
BuildRequires: dt-schema = 2026.09-1.fc46
BuildRequires: bash bc bison flex clang llvm lld make gcc gcc-c++ perl
BuildRequires: compiler-rt
BuildRequires: libasan libubsan
BuildRequires: nodejs
BuildRequires: elfutils-libelf-devel openssl-devel openssl ncurses-devel
BuildRequires: pkgconfig(libsystemd)
BuildRequires: alsa-topology-utils
BuildRequires: alsa-lib-devel alsa-utils dt-schema
BuildRequires: rsync tar xz zstd kmod git-core jq gnupg2 dtc
BuildRequires: libfdt-devel
BuildRequires: python3
BuildRequires: dracut systemd systemd-udev util-linux coreutils grep sed findutils binutils ripgrep gzip cpio f2fs-tools
Requires: %{name}-core = %{version}-%{release}
Requires: %{name}-modules = %{version}-%{release}
Requires: %{name}-dtbs = %{version}-%{release}
Requires: %{name}-boot = %{version}-%{release}
Provides: installonlypkg(kernel)

Requires: uke-speaker-runtime >= 0.4-2
BuildRequires: clang = 23.1.5-1.fc46
BuildRequires: llvm = 23.1.5-1.fc46
BuildRequires: lld = 23.1.5-1.fc46
Requires: uke-control(critical-rollback-v1) >= 1
Requires: uke-control(critical-crash-count-v1) >= 1
# UKE_STABLE734_FULL_SOURCES_BEGIN
Source201: uke-stable734.tar.xz
Source202: stable734-full-qualification.json
Source203: stable734-native-proof.rpm
Source204: stable734-copr-public-key.asc
# UKE_STABLE734_FULL_SOURCES_END
# UKE_RGB_CLIENT_DEPENDENCY_BEGIN
Requires: uke-control(rgb-charge-status-v1) >= 1
# UKE_RGB_CLIENT_DEPENDENCY_END
# UKE_ABM_FULL7343_HEADER_BEGIN
Source205: uke-native-abm734.tar.xz
Source206: abm734-native-proof.rpm
Source207: abm734-full-qualification.json
# UKE_ABM_FULL7343_HEADER_END
# UKE_SUPER_FULL7344_HEADER_BEGIN
BuildRequires: android-tools e2fsprogs device-mapper
Source208: uke-super-full734.tar.xz
Source209: super734-native-proof.rpm
Source210: super734-initrd-proof.rpm
Source211: super734-full-qualification.json
# UKE_SUPER_FULL7344_HEADER_END
# UKE_DISPLAY_FULL7345_HEADER_BEGIN
Source212: uke-display-full7345.tar.xz
Source213: display-handoff-native-proof.rpm
Source214: display-full7345-qualification.json
# UKE_DISPLAY_FULL7345_HEADER_END
# UKE_CAMERA_FULL7346_HEADER_BEGIN
Source215: uke-camera-full7346.tar.xz
Source216: camera-native22-proof.rpm
Source217: camera-full7346-qualification.json
# UKE_CAMERA_FULL7346_HEADER_END
# UKE_CAMERA_FULL7347_HEADER_BEGIN
Source218: uke-camera-full7347.tar.xz
Source219: camera-native23-proof.rpm
Source220: camera-full7347-qualification.json
# UKE_CAMERA_FULL7347_HEADER_END
# UKE_CAMERA_FULL7348_HEADER_BEGIN
Source221: uke-camera-full7348.tar.xz
Source222: camera-native26-proof.rpm
Source223: camera-full7348-qualification.json
# UKE_CAMERA_FULL7348_HEADER_END
# UKE_CAMERA_FULL7349_HEADER_BEGIN
Source224: uke-camera-full7349.tar.xz
Source225: camera-native32-proof.rpm
Source226: camera-full7349-qualification.json
# UKE_CAMERA_FULL7349_HEADER_END
# UKE_CAMERA_FULL73410_HEADER_BEGIN
Source227: uke-camera-full73410.tar.xz
Source228: camera-native33-proof.rpm
Source229: camera-full73410-qualification.json
# UKE_CAMERA_FULL73410_HEADER_END
# UKE_CAMERA_ICC_HF_FULL734_HEADER_BEGIN
Source230: uke-camera-icc-hf734.tar.xz
Source231: camera-icc-hf-native34-proof.rpm
# UKE_CAMERA_ICC_HF_FULL734_HEADER_END
# UKE_EARLY_PLYMOUTH734_HEADER_BEGIN
Source232: uke-early-plymouth-source.tar.xz
Source233: early-plymouth734-proof.rpm
Source234: prepare-early-plymouth-full734.sh
BuildRequires: plymouth-scripts plymouth-graphics-libs plymouth-plugin-label fontconfig
# Match the standalone build input used by the signed early-boot proof.
BuildRequires: (uke-plymonth = 1.1.0-3.fc46 without uke-core-meta)
# UKE_EARLY_PLYMOUTH734_HEADER_END
# UKE_GUNYAH_WATCHDOG_FULL734_HEADER_BEGIN
Source235: uke-gunyah-watchdog-source.tar.xz
Source236: gunyah-watchdog-native-proof.rpm
# UKE_GUNYAH_WATCHDOG_FULL734_HEADER_END
# UKE_SPEAKER_RGB_FULL734_HEADER_BEGIN
Source237: uke-speaker-rgb-source.tar.xz
Source238: fs19xx-stop-reset-native-proof.rpm
Source239: rgb-demand-native-proof.rpm
# UKE_SPEAKER_RGB_FULL734_HEADER_END
# UKE_FS19XX_TELEMETRY734_HEADER_BEGIN
Source240: 0033-fs19xx-bound-preset-records.patch
Source241: 0034-fs19xx-prediction-readback.patch
Source242: 0035-fs19xx-coil-temperature-readback.patch
Source243: fs19xx-telemetry-prelink-proof.rpm
Source244: apply-fs19xx-telemetry-full734.sh
Source245: verify-stable7353-parent.sh
Source246: stable7353-prepared.sha256
Source247: 0036-audioreach-tdm-payload-size.patch
Source248: audio-tdm-sink-contract.sh
Source249: 0125-uke-ucsi-contract-cache.patch
Source250: ucsi-pd-contract.sh
Source251: uke-audio-power-735-prelink-7.3.5-1.fc46.aarch64.rpm
Source252: uke-audio-power7352.sha256
Source253: 0127-uke-ucsi-refresh-contract-after-recheck.patch
Source254: 0128-uke-ucsi-validate-source-pdo-reply.patch
Source255: ucsi-pd-contract-7353.sh
Source256: ucsi-pdo-wire.sh
Source257: uke-ucsi-contract-735-check-0.1-5.fc46.aarch64.rpm
Source258: uke-ucsi7353.sha256
# UKE_FS19XX_DIRECTION735_HEADER_BEGIN
Source259: 0037-fs19xx-protected-subgraph-directions.patch
Source260: audio-protected-direction.mjs
Source261: apply-fs19xx-directions-735.sh
Source262: uke-vi-tdm-wire-check-0.1-6.fc46.aarch64.rpm
Source263: 0023-iris-use-enforced-dma-aperture.patch
Source264: uke-native-touch-pd-layers.tar.xz
Source265: uke-vi-tdm-wire-check-0.1-8.fc46.aarch64.rpm
Source266: uke-ucsi-contract-735-check-0.1-6.fc46.aarch64.rpm
Source267: uke-vi-tdm-wire-check-0.1-11.fc46.aarch64.rpm
Source268: uke-fs19xx-device-scenarios.tar.xz
Source269: apply-fs19xx-telemetry-scenario-735.sh
Source270: 0039-fs19xx-read-feedback-converter-status.patch
Source271: audio-fs19xx-feedback-status.sh
Source272: uke-fs19xx-stop-reset-source-check-0.1-3.fc46.aarch64.rpm
Source273: 0003-qcom-battmgr-wait-for-initial-uke-service.patch
Source274: uke-upower-refresh-source-check-1.91.5-4.fc46.aarch64.rpm
Source275: 0040-q6apm-start-uke-feedback-before-playback.patch
Source276: uke-vi-tdm-wire-check-0.1-12.fc46.aarch64.rpm
Source277: 0041-fs19xx-encode-qualified-uke-gain-ceiling.patch
Source278: uke-vi-tdm-wire-check-0.1-13.fc46.aarch64.rpm
Source279: 0004-uke-qcom-battmgr-read-fitted-oem-charge-status.patch
Source280: uke-upower-refresh-source-check-1.91.5-5.fc46.aarch64.rpm
Source281: uke-oem-charge-status-qualification.config.patch
Source282: 0005-uke-qcom-battmgr-observe-fitted-usb-source-class.patch
Source283: uke-upower-refresh-source-check-1.91.5-6.fc46.aarch64.rpm
Source284: 0007-uke-qcom-battmgr-publish-after-firmware-identity.patch
Source285: uke-upower-refresh-source-check-1.91.5-9.fc46.aarch64.rpm
Source286: uke-battery-ready-publication.config.patch
Source287: 0008-uke-qcom-battmgr-observe-fitted-charge-modes.patch
Source288: uke-upower-refresh-source-check-1.91.5-10.fc46.aarch64.rpm
Source289: unstable-boot-family-merged-contract.sh
Source290: 0130-uke-ucsi-report-source-pdo-discovery.patch
Source291: uke-ucsi-contract-735-check-0.1-7.fc46.aarch64.rpm
Source292: 0009-uke-qcom-battmgr-observe-fast-charge-status.patch
Source293: uke-upower-refresh-source-check-1.91.5-11.fc46.aarch64.rpm
Source294: 0042-fs19xx-preserve-alsa-state-on-restricted-read.patch
Source295: uke-fs19xx-alsa-state-check-0.1-3.fc46.aarch64.rpm
Source296: 0010-uke-charge-observe-confirmed-panel-state.patch
Source297: uke-charge-screen-dt-check-0.1-3.fc46.aarch64.rpm
Source298: uke-o82-charge-screen-check-0.1-1.fc46.aarch64.rpm
Source299: uke-o82-charge-screen-object-check-0.1-3.fc46.aarch64.rpm
# UKE_FS19XX_DIRECTION735_HEADER_END
# UKE_FS19XX_TELEMETRY734_HEADER_END
Source396: senemos-publication-abi.patch
Source397: normal-publication-views.sh
Source398: normal-merged-contract.sh
Source399: uke-normal-vi-overlay735.tar.xz
Source400: uke-normal-charge-observation735.tar.xz
Source401: uke-normal-display735.tar.xz
Source402: uke-normal-usb-type735.tar.xz
Source403: uke-normal-ucsi-fixed-contract735.tar.xz
Source404: uke-normal-threshold-observation735.tar.xz
Source405: uke-normal-battery-limit735.tar.xz
Source406: uke-normal-camss735.tar.xz
Source407: uke-normal-root-probe735.tar.xz
Source408: uke-normal-observations735.tar.xz
Source409: uke-senemos-dtbo-1.0-1.fc46.aarch64.rpm
Source410: install-normal-recovered-dtbo.sh
Source411: uke-kernel-migration-check-7.3.5-20.fc46.aarch64.rpm
Source412: uke-normal-transport-charge735.tar.xz
Source413: uke-normal-feedback-geni735.tar.xz
Source414: uke-normal-ktz-minimum735.tar.xz
Source415: uke-normal-gpi735.tar.xz
Source416: uke-normal-battery-status-burst735.tar.xz
Source417: uke-normal-fcc-remoteproc735.tar.xz
Source418: uke-normal-fixed-cap-epoch735.tar.xz
Source419: uke-normal-rgb-ssc735.tar.xz
Source420: uke-normal-touch-watchdog735.tar.xz
Source421: uke-normal-bsg-monitor735.tar.xz
Source422: uke-normal-touch-distinct735.tar.xz
Source423: uke-normal-display-cap-status735.tar.xz
Source424: uke-normal-pack-voltage73526.tar.xz
Source425: uke-normal-dp-hbr3-trial73526.tar.xz
Source426: uke-pmic-glink-safe-detach73527.tar.xz
Source427: uke-hbr3-mainlink-fallback73526.tar.xz
Source428: uke-dpu-optional-dspp73526.tar.xz
Source429: uke-ov08d10-reset-unwind73527.tar.xz
Source430: uke-front-vdig-guard29.tar.xz
Source431: uke-mst-detect-controller73529.tar.xz
Source432: uke-juo-display73530.tar.xz
Source433: uke-usb-dp-stability73531.tar.xz
Source434: uke-display-fault73531.tar.xz
Source435: uke-dpu-atomic-total73533.tar.xz
Source436: uke-mst-single-payload73533.tar.xz
Source437: uke-dp-attach-ownership73533.tar.xz
Source438: uke-mst-rate-governor73533.tar.xz
Source439: uke-mst-encoder-prepass73534.tar.xz
Source440: uke-altmode-hpd-route-error73534.tar.xz
Source441: uke-battmgr-deadline73534.tar.xz

%description
Source-built kernel with the reviewed O82 native display profile.
The core package contains a source-built initramfs and Android v4 container
with matching modules. It contains no OEM firmware or device-private data.
The native updater respects administrator policy. Guarded automatic staging
is enabled by default, without an automatic reboot. Build success does not
establish physical tablet acceptance.

%package core
Summary: Uke kernel Image, modules, device tree and boot bundle
Provides: uke-kernel(merged-layout-v1) = 1
Provides: %{name}-modules = %{version}-%{release}
Provides: %{name}-modules%{?_isa} = %{version}-%{release}
Provides: %{name}-boot = %{version}-%{release}
Provides: %{name}-boot%{?_isa} = %{version}-%{release}
Provides: %{name}-dtbs = %{version}-%{release}
Provides: %{name}-dtbs%{?_isa} = %{version}-%{release}
Requires: uke-control >= 2.17.0-60
Requires: kmod
Requires: uke-firmware >= 3.0.304.0
Requires: uke-control(super-root-boot-v1) >= 1
Requires: uke-kernel-update(o82-private-color-v5) >= 1
Requires: uke-o82-color-profile >= 0.7.0-1
Requires: uke-installation-profile(rtc-secure-offset-v1) >= 1
Requires: uke-nfc-ir >= 1.0.0-1
Requires: uke-kernel-update >= 1.8.101
Requires: uke-kernel-update(alternating-checkpoint-v2) >= 1
Requires: uke-kernel-update(inactive-slot-no-image-backup-v1) >= 1
Requires: uke-kernel-update(device-local-video-import-v1) >= 1
Requires: uke-kernel-update(guarded-automatic) >= 1
Requires: uke-kernel-update(transaction-v1) >= 1
Requires: uke-kernel-update(final-transaction-v2) >= 1
Requires: uke-boot-integration(kernel-touch-input-v2) >= 1
Requires: (uke-power-profile-backend(native-handoff-v1) >= 1 if uke-power-profile-backend)
Provides: installonlypkg(kernel)
Provides: kernel-uname-r(%{krel})
Provides: uke-kernel(platform-profile-qos-v1) = 1
Provides: uke-kernel(nfc-ir-v1) = 1
Provides: uke-kernel(memlat-v1) = 1
Provides: uke-kernel(rtc-secure-offset-v1) = 1
Provides: uke-kernel(ssc-iio-v1) = 1
Provides: uke-kernel(ssc-heading-iio-v1) = 1
Provides: uke-kernel(ssc-proximity-input-v1) = 1
Provides: uke-kernel(camcc-crmc-resources-v1) = 1
Provides: uke-kernel(ssc-stream-buffer-fresh-v1) = 1
Provides: uke-kernel(ssc-time-reference-diagnostic-v1) = 1
Provides: uke-kernel(hwkm-probe-profile-v1) = 1
Provides: uke-kernel(qtee-tpm-information-v1) = 1
Provides: uke-kernel(charge-existing-band-online-v1) = 1
Provides: uke-kernel(battery-status-event-v1) = 1
Provides: uke-kernel(charge-standard-observed-thresholds-v1) = 1
Provides: uke-kernel(charge-demand-protection-v1) = 1
Provides: uke-kernel(charge-protection-passive-v1) = 1
Provides: uke-kernel(charge-protection-observe-v2) = 1
Provides: uke-kernel(storage-encryption-config-v1) = 1
Provides: uke-kernel(nfc-ir-v2) = 1
Provides: uke-displayport-audio = 0.1.0-13%{?dist}
Requires: (wireplumber >= 0.5 if wireplumber)
Requires: (pipewire-pulseaudio >= 1.6.10-1.uke1 if pipewire-pulseaudio)
Recommends: alsa-ucm

# UKE_SUPER_FULL7344_CAPABILITY_BEGIN
Provides: uke-kernel(super-root-seed4-v1) = 1
# UKE_SUPER_FULL7344_CAPABILITY_END
%description core
Image, modules, device tree, matching boot images, configuration and source record.

%package singleboot
Provides: uke-kernel-default(waydroid-netd) = 1
Provides: uke-senemos-dtbo = 1.0-1%{?dist}
Provides: uke-senemos-dtbo%{?_isa} = 1.0-1%{?dist}
Provides: uke-dtbo(recovered-source-cohort-v1) = 1
Obsoletes: uke-senemos-dtbo <= 1.0-1%{?dist}
Summary: Matched Uke userdata boot profile
License: MIT AND Apache-2.0 AND BSD-3-Clause AND LicenseRef-Proprietary
Requires: %{name} = %{version}-%{release}
Requires: uke-installation-profile >= 1.3.1
Requires: uke-kernel-update(root-filesystem-v2) >= 1

%description singleboot
Selects the userdata image from this source family's exact kernel tuple.
Image, modules, DTBs and both root profiles are built once. When automatic
updates are enabled, installation uses the guarded native transaction to write
and select the inactive Linux slot. The accepted running slot and modules are
retained for rollback. Administrator policy is preserved; no reboot is requested.

%prep
uke_prep_start=$SECONDS
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
(cd native-profile;sha256sum -c --strict --quiet SHA256SUMS)
bash native-profile/tests/ssc-heading-math.sh
bash native-profile/packaging/native/preflight-ssc-heading733.sh "$PWD"
bash native-profile/prepare.sh "$PWD"
# UKE_FS19XX_DIRECTION735_PREP_BEGIN
printf '%s  %s\n' 70d140435e4c7c7046ec6937078f9730bf11d8dc115081aaa9dfc5a8f5fd4e38 %{SOURCE259} | sha256sum -c --strict --quiet -
printf '%s  %s\n' b657f07a1818aa3aaa755f13c33345752c1b0ac81a81792ef6e959396edb6ecc %{SOURCE260} | sha256sum -c --strict --quiet -
printf '%s  %s\n' c6bfcdc7c54632e39ac30a8ac62e2ee0dcddf4c9e0b7bb317485c0892571620f %{SOURCE261} | sha256sum -c --strict --quiet -
printf '%s  %s\n' de55b832bd4c4135fa090696daa8e82d7ee868f25b529c13d753cf9c6ea4c63b %{SOURCE262} | sha256sum -c --strict --quiet -
rpm2cpio %{SOURCE262} | cpio -i --quiet --to-stdout './usr/share/uke-vi-tdm-wire-check/results.txt' > native-generated/fs19xx-direction735-proof.txt
grep -Fx 'Compiled topology: graph 40 speaker RX=2 and VI TX=1, all other bytes identical.' native-generated/fs19xx-direction735-proof.txt
test "$(grep -c '^Protected graph direction admission:' native-generated/fs19xx-direction735-proof.txt)" = 2
grep -Fx "Cumulative direction layer: assembled speaker/microphone topology and exact post-telemetry runtime verified." native-generated/fs19xx-direction735-proof.txt
grep -Fx '70d140435e4c7c7046ec6937078f9730bf11d8dc115081aaa9dfc5a8f5fd4e38  0037-fs19xx-protected-subgraph-directions.patch' native-generated/fs19xx-direction735-proof.txt
grep -Fx 'b657f07a1818aa3aaa755f13c33345752c1b0ac81a81792ef6e959396edb6ecc  audio-protected-direction.mjs' native-generated/fs19xx-direction735-proof.txt
bash %{SOURCE261} "$PWD" topology %{SOURCE259} %{SOURCE260}
# UKE_FS19XX_DIRECTION735_PREP_END
# UKE_IRIS_DMA_FLOOR735_PREP_BEGIN
printf '%s  %s\n' c17a154d3a46e66d7911eaeb9f37eae0a0c34afb266de84ba88dc8fc8edda598 %{SOURCE263} | sha256sum -c --strict --quiet -
grep -Fx 'c17a154d3a46e66d7911eaeb9f37eae0a0c34afb266de84ba88dc8fc8edda598  0023-iris-use-enforced-dma-aperture.patch' native-generated/fs19xx-direction735-proof.txt
test "$(grep -Fxc 'Original Iris reservation cannot allocate below the DMA-IOMMU floor.' native-generated/fs19xx-direction735-proof.txt)" = 4
test "$(grep -Fxc 'Iris DMA aperture and legacy allocation/unwind cases passed.' native-generated/fs19xx-direction735-proof.txt)" = 4
# UKE_IRIS_DMA_FLOOR735_PREP_END
mkdir -p native-generated/camera-sensors-before731
cp drivers/media/i2c/ov08d10.c drivers/media/i2c/ov13b10.c native-generated/camera-sensors-before731/
for sensor_patch in native-profile/src/camera/sensors/000[123]-*.patch; do git apply --check "$sensor_patch"; git apply "$sensor_patch"; done
test "$(find native-profile/src/camera/sensors -name '000[123]-*.patch' | wc -l)" = 3
mkdir -p native-generated/camcc-baseline/drivers/clk/qcom
cp drivers/clk/qcom/gdsc.c drivers/clk/qcom/gdsc.h native-generated/camcc-baseline/drivers/clk/qcom/
for patch in native-profile/src/camera/provider/000[123]-clk-qcom-gdsc-*.patch; do git apply --check "$patch"; git apply "$patch"; done
test "$(find native-profile/src/camera/provider -name '000[123]-clk-qcom-gdsc-*.patch' | wc -l)" = 3
git apply --check native-profile/src/camera/provider/0004-clk-qcom-gdsc-permanent-storage.patch
git apply native-profile/src/camera/provider/0004-clk-qcom-gdsc-permanent-storage.patch
git apply --check native-profile/src/camera/sensors/0004-ov08d10-exposure-read-errors.patch
git apply native-profile/src/camera/sensors/0004-ov08d10-exposure-read-errors.patch
if grep -l GDSC_CONTROLLER_PM drivers/clk/qcom/*-*.c; then exit 1; fi
cmp native-profile/src/input/nt36532-uke-spi.c drivers/input/touchscreen/nt36532-uke/nt36532-uke-spi.c
tar -xJf %{SOURCE5}
cmp boot-recipe/lock.json %{SOURCE6}
(cd boot-recipe; jq -r '.source_assets[] | .sha256 + "  " + .path' lock.json | sha256sum -c -)

printf 'UKE_BUILD_STAGE source_prepare elapsed_s=%d\n' "$((SECONDS-uke_prep_start))"

camss_dir=drivers/media/platform/qcom/camss
mkdir -p native-generated/camss-before731/$camss_dir
cp $camss_dir/camss-csiphy.c $camss_dir/camss-csiphy-3ph-1-0.c native-generated/camss-before731/$camss_dir/
patch -p1 --fuzz=0 -i native-profile/src/camera/camss/0001-media-camss-return-phy-setup-errors.patch
patch -p1 --fuzz=0 -i native-profile/src/camera/camss/0002-media-camss-sm7675-resources.patch
for header in csiphy-sm7675.h camss-sm7675-phy-ops.h camss-sm7675-data.h; do cp native-profile/src/camera/camss/$header $camss_dir/$header; done
bash native-profile/src/camera/prepare-controller731.sh "$PWD"
mkdir -p native-generated/cci-before731/drivers/i2c/busses
cp drivers/i2c/busses/i2c-qcom-cci.c native-generated/cci-before731/drivers/i2c/busses/
printf '45b2dc46ea637f411a39f9352156e91d85a191b4fd3d2bfb44d5b7fc81d57693  drivers/i2c/busses/i2c-qcom-cci.c\n' | sha256sum -c --strict
patch -p1 --fuzz=0 -i native-profile/src/camera/cci/0001-i2c-qcom-cci-initialize-all-completions.patch
mkdir -p native-generated/at24-before731/drivers/nvmem
cp drivers/nvmem/at24.c native-generated/at24-before731/drivers/nvmem/
printf 'f37ed370a86b2b850625ecd7e5e4d810b5feeb65c10f719a9e505aa8db2795a0  drivers/nvmem/at24.c\n' | sha256sum -c --strict
printf '98452b4e32c41de9f74608356d2126e0743f7f229391577f0bb451bc180f2e3e  Documentation/devicetree/bindings/eeprom/at24.yaml\n' | sha256sum -c --strict
patch -p1 --fuzz=0 -i native-profile/src/camera/eeprom/0001-at24-readonly-vcc.patch
patch -p1 --fuzz=0 -i native-profile/src/camera/eeprom/0002-at24-readonly-vcc-binding.patch
install -m644 native-profile/src/camera/eeprom/at24-vcc-readonly.h drivers/nvmem/at24-vcc-readonly.h
rpm -q dt-schema
dt-doc-validate Documentation/devicetree/bindings/eeprom/at24.yaml
cp drivers/regulator/qcom-rpmh-regulator-uke.c native-generated/rpmh-before-front731.c
patch -p1 --fuzz=0 -i native-profile/src/camera/eeprom/0003-rpmh-front-vio.patch
CC=clang bash native-profile/tests/o82-avr-contract.sh "$PWD"
CXX=clang++ bash native-profile/tests/dpu-video-timing-contract.sh "$PWD"
CC=clang bash native-profile/tests/msm-retirement-proof-contract.sh "$PWD"
CC=clang bash native-profile/tests/dpu-reservation-contract.sh "$PWD" "$PWD/native-generated/dpu-reservation-before56"
CC=clang bash native-profile/tests/dpu-color-topology-contract.sh "$PWD/drivers/gpu/drm/msm/disp/dpu1/dpu_crtc.c"
bash native-profile/tests/o82-profile-loader-contract.sh native-profile
bash native-profile/tests/o82-lutbus-contract.sh
bash native-profile/tests/o82-regdma-transport-contract.sh native-profile "$PWD"
bash native-profile/tests/o82-atomic-contract.sh native-profile "$PWD"
bash native-profile/tests/cdsp-actlr-qualify.sh "$PWD"
bash native-profile/src/camera/provider/apply-gcc-config731.sh "$PWD"
bash native-profile/packaging/native/prepare-queued-kernel731.sh "$PWD" native-profile
bash native-profile/src/audio/apply-config-smmu731.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-client-data731.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-client-byte-ready731.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-protected-stop731.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-idle-stop731.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/display/apply-vrr-api731.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-stop-deadline733.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-pcm-period733.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/audio/apply-enable-readback733.sh "$PWD" "$PWD/native-profile"
bash native-profile/src/input/apply-hall-initial-gpio733.sh "$PWD"
tar -xJf %{SOURCE190}
(cd native-hardware; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/native-hardware-delivery-20261113.json | sha256sum -c --strict --quiet -)
bash native-hardware/tests/native-hardware-source-view.sh

tar -xJf %{SOURCE191}
(cd ssc-time-reference-full; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/ssc-time-reference-delivery-20261113.json | sha256sum -c --strict --quiet -)
(cd ssc-time-reference-full; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/ssc-time-reference-20261113.json | sha256sum -c --strict --quiet -)

tar -xJf %{SOURCE192}
(cd hwkm-early; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/hwkm-early-20261115.json | sha256sum -c --strict --quiet -)
tar -xJf %{SOURCE200}
(cd crm-passive; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/camera-crm-passive-20261114.json | sha256sum -c --strict --quiet -)

tar -xJf %{SOURCE193}
(cd qtee-information; jq -r '.source_assets[]|.sha256+"  "+.path' manifests/qtee-information-20261115.json | sha256sum -c --strict --quiet -)

sha256sum -c --strict --quiet %{SOURCE246}
# Validate the two small deltas before the quad and PCM source layers record their parent files.
(
set -o pipefail
(cd %{_sourcedir}; sha256sum -c --strict --quiet %{SOURCE252})
check=native-generated/audio-power7352
install -d "$check"
for receipt in parent.sha256 candidate.sha256 cumulative-fixtures.txt elf.txt; do
    rpm2cpio %{SOURCE251} | cpio -i --quiet --to-stdout "./usr/share/uke-audio-power-735-prelink/$receipt" > "$check/$receipt"
    test -s "$check/$receipt"
done
test "$(grep -c 'AArch64' "$check/elf.txt")" -eq 4
test "$(grep -c '^TDM speaker and VI parameter fixtures passed$' "$check/cumulative-fixtures.txt")" -eq 2
sha256sum -c --strict --quiet "$check/parent.sha256"
for overlay in %{SOURCE247} %{SOURCE249}; do
    git apply --check --whitespace=error "$overlay"
    git apply --whitespace=error "$overlay"
done
sha256sum -c --strict --quiet "$check/candidate.sha256"
)

# Verify the Uke PDO changes against the signed source-check result.
(
set -o pipefail
(cd %{_sourcedir}; sha256sum -c --strict --quiet %{SOURCE258})
check=native-generated/ucsi7353
install -d "$check"
rpm2cpio %{SOURCE257} | cpio -i --quiet --to-stdout './usr/share/uke-source-checks/ucsi-735.txt' > "$check/qualification"
rpm2cpio %{SOURCE257} | cpio -i --quiet --to-stdout './usr/share/uke-source-checks/ucsi-735.sha256' > "$check/prepared.sha256"
test "$(grep -c '^Actual source PDO parser validated 13 complete, malformed and failed replies$' "$check/qualification")" -eq 2
test "$(wc -l < "$check/prepared.sha256")" -eq 4
for overlay in %{SOURCE253} %{SOURCE254}; do
    git apply --check --whitespace=error "$overlay"
    git apply --whitespace=error "$overlay"
done
sha256sum -c --strict --quiet "$check/prepared.sha256"
)

%build
# UKE_CAMERA_FULL7346_PREPARE_BEGIN
tar -xJf %{SOURCE215}
(cd camera-full7346;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7346_PREPARE_END
# UKE_CAMERA_FULL7347_PREPARE_BEGIN
tar -xJf %{SOURCE218}
(cd camera-full7347;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7347_PREPARE_END
# UKE_CAMERA_FULL7348_PREPARE_BEGIN
tar -xJf %{SOURCE221}
(cd camera-full7348;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7348_PREPARE_END
# UKE_CAMERA_FULL7349_PREPARE_BEGIN
tar -xJf %{SOURCE224}
(cd camera-full7349;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7349_PREPARE_END
# UKE_CAMERA_FULL73410_PREPARE_BEGIN
tar -xJf %{SOURCE227}
(cd camera-full73410;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL73410_PREPARE_END
# UKE_DISPLAY_FULL7345_PREPARE_BEGIN
tar -xJf %{SOURCE212}
(cd display-full7345;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_DISPLAY_FULL7345_PREPARE_END
# UKE_LEAN_FULL_RECIPE
# Resolve every historical and production config with the same new Kconfig definitions.
printf '%s  %s\n' \
    4d01d0fbff61af6f33a9e86812f65739ec7fa5ce2fd22347835f22e5764e1759 %{SOURCE277} \
    22babe520c7a5144559454f232bcfec9bebb025eb44e26afab8aad25d699b360 %{SOURCE279} \
    0ee9cd6084958226f891c1a4b7787f75389cd557cbb27666a0a1d142c34fce02 %{SOURCE281} |
    sha256sum -c --strict --quiet -
for file in %{SOURCE277} %{SOURCE279} %{SOURCE284}; do
    git apply --include='*/Kconfig' --check --whitespace=error "$file"
    git apply --include='*/Kconfig' --whitespace=error "$file"
done
git apply --check --whitespace=error %{SOURCE281}
git apply --whitespace=error %{SOURCE281}
printf '%s  %s\n' 9c57e03e31045933bdfd184ec4b7e0d8097cb6b54c316912416be924ce50031a %{SOURCE286} | sha256sum -c --strict --quiet -
git apply --check --whitespace=error %{SOURCE286}
git apply --whitespace=error %{SOURCE286}
for role in cdsp waydroid cdsp-before; do
  ref="$PWD/native-generated/nfc-$role-reference"
  mkdir -p "$ref"
  if [[ $role == cdsp-before ]]; then
    cp native-profile/configs/governor-before-nfc-cdsp.config "$ref/.config"
  else
  cp "native-profile/configs/nfc-$role-reference.config" "$ref/.config"
  fi
  bash scripts/config --file "$ref/.config" --set-str INITRAMFS_SOURCE "%{_uke_out}/boot-initramfs.cpio.gz"
  make -s O="$ref" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
  grep -Fxq 'CONFIG_BATTERY_QCOM_BATTMGR_UKE_OEM_STATUS=y' "$ref/.config"
  grep -Fxq 'CONFIG_BATTERY_QCOM_BATTMGR_UKE_READY_PUBLICATION=y' "$ref/.config"
  grep -Fxq '# CONFIG_SND_SOC_FS19XX_UKE_QUALIFIED_GAIN is not set' "$ref/.config"
done
# Keep the sealed historical CDSP report reproducible alongside the new configs.
ref="$PWD/native-generated/nfc-cdsp-before-reference"
status_on='CONFIG_BATTERY_QCOM_BATTMGR_UKE_OEM_STATUS=y'
publication_on='CONFIG_BATTERY_QCOM_BATTMGR_UKE_READY_PUBLICATION=y'
gain_off='# CONFIG_SND_SOC_FS19XX_UKE_QUALIFIED_GAIN is not set'
test "$(grep -Fxc "$status_on" "$ref/.config")" = 1
test "$(grep -Fxc "$gain_off" "$ref/.config")" = 1
test "$(grep -Fxc "$publication_on" "$ref/.config")" = 1
grep -Fvx -e "$status_on" -e "$gain_off" -e "$publication_on" "$ref/.config" > "$ref/historical.config"
test "$(wc -l < "$ref/.config")" = "$(( $(wc -l < "$ref/historical.config") + 3 ))"
bash native-profile/tests/cdsp-pogo-toolchain-contract.sh "$ref/historical.config"
bash native-profile/tests/cdsp-pogo-config-contract.sh "$ref/historical.config"
bash native-profile/tests/governor-config-contract.sh "$ref/.config" native-generated/nfc-cdsp-reference/.config
sha256sum "$ref/.config" "$ref/historical.config" > "$ref/historical-inputs.sha256"
bash native-profile/packaging/native/prepare-memory-manager733.sh "$PWD" %{_uke_out}
bash native-profile/packaging/native/check-dual-light-delivery733.sh "$PWD" %{_uke_out} prepared
export ARCH=arm64 LLVM=1 LLVM_IAS=1
test -z "${UKE_PREBUILT_SWITCH_ROOT:-}"
export KBUILD_BUILD_USER=senemos KBUILD_BUILD_HOST=copr-builder KBUILD_BUILD_VERSION=1
export SOURCE_DATE_EPOCH=1794334272
export KBUILD_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH" '+%%Y-%%m-%%d %%H:%%M:%%S UTC')"
mkdir -p %{_uke_out}
# UKE_SUPER_FULL7344_INITRD_BEGIN
tar -xJf %{SOURCE208}
(cd full4;sha256sum -c --strict --quiet SHA256SUMS)
for proof_role in native initrd;do
 if test "$proof_role" = native;then archive=%{SOURCE209};else archive=%{SOURCE210};fi
 printf '%s  %s\n' "$(jq -er ".$proof_role.proof_sha256" %{SOURCE211})" "$archive" | sha256sum -c --strict --quiet -
 mkdir -p "native-generated/super734-$proof_role-proof"
 (cd "native-generated/super734-$proof_role-proof";rpm2cpio "$archive" | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
done
super_native=$PWD/native-generated/super734-native-proof/usr/share/uke-kernel-migration-check/super-root734
super_initrd=$PWD/native-generated/super734-initrd-proof/usr/share/uke-super-root-source-check
test "$(cat "$super_native/source-commit")" = "$(jq -er .native.source_commit %{SOURCE211})"
test "$(cat "$super_initrd/source-commit")" = "$(jq -er .initrd.source_commit %{SOURCE211})"
cmp "$super_native/SHA256SUMS" full4/root15/SHA256SUMS
cmp "$super_initrd/early/SHA256SUMS" full4/early/SHA256SUMS
jq -e '.prepared_parent_header_preserved and .actual_arm64_objects==2 and .exact_old_and_new_capability_notes' "$super_native/qualification.json"
jq -e '.original_physical_root_guard_preserved and .actual_dracut_units_verified and .new_codec_modes==4 and .no_python_payload' "$super_initrd/early/measurement.json"
bash full4/early/src/boot/super-root734/integrate-initrd.sh "$PWD/boot-recipe" "$PWD/full4/early/builder"
bash full4/early/src/boot/super-root734/apply-boot-profiles.sh "$PWD/boot-recipe"
# UKE_SUPER_FULL7344_INITRD_END
# UKE_EARLY_PLYMOUTH734_COMPOSE_BEGIN
printf '%s  %s\n' 9ad1d6c75699b8cc5325de390ee8db0328886ba8130c1413d6001e69e61b7a8c %{SOURCE232} | sha256sum -c --strict --quiet -
printf '%s  %s\n' 70eb692f01b6811816a19459b489b9f45a9faea937d2eb7ef370216de9afaec3 %{SOURCE233} | sha256sum -c --strict --quiet -
tar -xJf %{SOURCE232}
(cd early-plymouth; sha256sum -c --strict --quiet SHA256SUMS)
mkdir native-generated/early-plymouth-proof
(cd native-generated/early-plymouth-proof; rpm2cpio %{SOURCE233} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
plymouth_proof=native-generated/early-plymouth-proof/usr/share/uke-early-plymouth-source-check
cmp early-plymouth/SHA256SUMS "$plymouth_proof/SHA256SUMS"
cmp early-plymouth/layer/pre.sha256 "$plymouth_proof/pre.sha256"
cmp early-plymouth/layer/post.sha256 "$plymouth_proof/post.sha256"
jq -e '.architecture=="aarch64" and .root_guard_preserved and .extra_bytes==3462675' "$plymouth_proof/measurement.json"
printf '%s  %s\n' 760f6feb936b36a5366e93c4db4403325aff859c279b967ad9bd3b696ca9da25 %{SOURCE234} | sha256sum -c --strict --quiet -
install -m644 %{SOURCE234} early-plymouth/prepare-full.sh
bash early-plymouth/prepare-full.sh compose "$PWD"
# UKE_EARLY_PLYMOUTH734_COMPOSE_END
# Keep the inherited source receipts valid during Plymouth verification.
printf '%s  %s\n' 66ae8cbdc1d0c237f5341020fd1a8be28af187b25caacbff2e846c49730d724b %{SOURCE396} \
    2fb031a6628f6cb903b8cc549fc629ca6ba916074ef7ed5443e5473f53f9ebe0 %{SOURCE397} \
    c73c7e135f6a3bcc8f901f24c24077708569853de5fe2807b3908bf0ebb9c4aa %{SOURCE398} | sha256sum -c --strict --quiet -
apply_normal_boot_recipe() {
    git apply --check --include='boot-recipe/**' %{SOURCE396}
    git apply --include='boot-recipe/**' %{SOURCE396}
    for path in src/boot/boot-status.cpp src/boot/build-payload.sh src/boot/make-initramfs-base.sh; do
        sha=$(sha256sum "boot-recipe/$path" | cut -d ' ' -f1)
        jq -e --arg path "$path" --arg sha "$sha" '
            select([.source_assets[] | select(.path==$path)] | length==1)
            | .source_assets |= map(if .path==$path then .sha256=$sha else . end)' \
            boot-recipe/lock.json > boot-recipe/lock.json.new
        mv boot-recipe/lock.json.new boot-recipe/lock.json
    done
}
cp boot-recipe/lock.json native-generated/normal-boot-lock-before.json
apply_normal_boot_recipe
if test ! -e %{uke_boot_userspace}; then
    bash boot-recipe/src/boot/make-initramfs-base.sh %{uke_boot_userspace} '%{krel}'
fi
# UKE_EARLY_PLYMOUTH734_RESTORE_BEGIN
git apply --reverse --include='boot-recipe/**' %{SOURCE396}
mv native-generated/normal-boot-lock-before.json boot-recipe/lock.json
bash early-plymouth/prepare-full.sh restore "$PWD"
apply_normal_boot_recipe
# UKE_EARLY_PLYMOUTH734_RESTORE_END
test "$(cat %{uke_boot_userspace}/kernel-release)" = '%{krel}'
(cd %{uke_boot_userspace}; sha256sum -c base-files.sha256)
jobs=%{?_smp_build_ncpus}%{!?_smp_build_ncpus:4}
test "$jobs" -le 8 || jobs=8
bash native-profile/tests/mainline-boot-status-contract.sh
bash %{SOURCE397} tests %{SOURCE396}
bash native-profile/src/sensors/apply-dual-light733.sh "$PWD"
bash native-profile/src/audio/apply-speaker-display733.sh "$PWD"
bash native-profile/src/display/apply-avr-transaction733.sh "$PWD"
bash native-profile/packaging/native/check-avr-transaction733.sh "$PWD" %{_uke_out} source
bash native-profile/src/health/apply-rproc-event733.sh "$PWD"
bash native-profile/packaging/native/check-rproc-event733.sh "$PWD" %{_uke_out} source
bash native-profile/src/audio/apply-speaker-quad733.sh "$PWD"
bash native-profile/packaging/native/check-speaker-quad733.sh "$PWD" %{_uke_out} source
# UKE_PROXIMITY_CRASH_HISTORY_DELIVERY
bash native-profile/src/sensors/apply-proximity-input733.sh "$PWD"
bash native-profile/src/health/apply-rproc-count733.sh "$PWD"
# UKE_MST_POWER_DELIVERY
bash native-profile/packaging/native/prepare-mst-power-delivery733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-surround-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-pcm-surround-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-gravity-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-quaternion-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-heading-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-charge-online-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-battery-event-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-charge-standard-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-charge-demand-full733.sh "$PWD" %{_uke_out} source
bash native-profile/packaging/native/prepare-charge-observe-full733.sh "$PWD" %{_uke_out} source
bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} source
bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} source
bash hwkm-early/packaging/native/prepare-hwkm-early733.sh "$PWD" %{_uke_out} source %{uke_boot_userspace}/base
uke_hwkm_parent=$(bash hwkm-early/packaging/native/hwkm-early-legacy-view733.sh "$PWD")
bash qtee-information/packaging/native/prepare-qtee-information733.sh "$PWD" %{_uke_out} source
# UKE_STABLE734_FULL_BUILD_BEGIN
tar -xJf %{SOURCE201}
bash native-profile/src/display/apply-native-vrr734.sh "$PWD"
mkdir native-generated/stable734-native-proof
(cd native-generated/stable734-native-proof;rpm2cpio %{SOURCE203} | cpio -idm --quiet --no-absolute-filenames)
native_proof=$PWD/native-generated/stable734-native-proof/usr/share/uke-kernel-migration-check
test "$(cat "$native_proof/source-commit")" = "$(jq -er .source_check.source_commit %{SOURCE202})"
# UKE_ABM_FULL7343_PARENT_BEGIN
tar -xJf %{SOURCE205}
(cd abm734;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_SUPER_FULL7344_TUPLE_BEGIN
# UKE_DISPLAY_FULL7345_TUPLE_BEGIN
# UKE_CAMERA_FULL7346_TUPLE_BEGIN
# UKE_CAMERA_FULL7347_TUPLE_BEGIN
# UKE_CAMERA_FULL7348_TUPLE_BEGIN
# UKE_CAMERA_FULL7349_TUPLE_BEGIN
# UKE_CAMERA_FULL73410_TUPLE_BEGIN
bash %{SOURCE245} "$PWD" "$native_proof/source.sha256" camera-full73410/verify-parent-source-tuple73410.sh '%{source_krel}'
# UKE_CAMERA_FULL73410_TUPLE_END
# UKE_CAMERA_FULL7349_TUPLE_END
# UKE_CAMERA_FULL7348_TUPLE_END
# UKE_CAMERA_FULL7347_TUPLE_END
# UKE_CAMERA_FULL7346_TUPLE_END
# UKE_DISPLAY_FULL7345_TUPLE_END
# UKE_SUPER_FULL7344_TUPLE_END
# UKE_ABM_FULL7343_PARENT_END
bash native-profile/packaging/native/preflight-audio-identity734.sh "$PWD"
# UKE_STABLE734_FULL_BUILD_END
# UKE_ABM_FULL7343_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE207})" %{SOURCE206} | sha256sum -c --strict --quiet -
mkdir native-generated/abm734-native-proof
(cd native-generated/abm734-native-proof;rpm2cpio %{SOURCE206} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
abm_proof=$PWD/native-generated/abm734-native-proof/usr/share/uke-kernel-migration-check/abm734
test "$(cat "$abm_proof/layer-source-commit")" = "$(jq -er .native.source_commit %{SOURCE207})"
cmp "$abm_proof/qualified-source.sha256" abm734/src/display/abm734-post.sha256
bash abm734/src/display/apply-native-abm734.sh "$PWD"
sha256sum -c --strict --quiet "$abm_proof/qualified-source.sha256"
if ! bash abm734/tests/native-abm734.sh "$PWD" > native-generated/abm734-native-results.txt 2>&1;then tail -n 100 native-generated/abm734-native-results.txt;exit 1;fi
cat native-generated/abm734-native-results.txt
# UKE_ABM_FULL7343_BUILD_END
# UKE_SUPER_FULL7344_ROOT_BEGIN
export LOCALVERSION=-%{senemos_build_release}-unstable
super_objects=$PWD/native-generated/super734-native-objects
test ! -e "$super_objects"
mkdir "$super_objects"
cp native-profile/native.config "$super_objects/.config"
bash native-profile/src/livepatch/configure734.sh "$PWD" "$super_objects/.config" "$PWD/native-profile"
bash scripts/config --file "$super_objects/.config" --set-str INITRAMFS_SOURCE ''
make -s O="$super_objects" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig prepare modules_prepare
bash full4/root15/tests/native-super-root734.sh "$PWD" "$super_objects"
sha256sum -c --strict --quiet "$super_native/source.sha256"
# UKE_SUPER_FULL7344_ROOT_END
# UKE_DISPLAY_FULL7345_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE214})" %{SOURCE213} | sha256sum -c --strict --quiet -
mkdir native-generated/display-handoff-native-proof
(cd native-generated/display-handoff-native-proof;rpm2cpio %{SOURCE213} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
display_proof=$PWD/native-generated/display-handoff-native-proof/usr/share/uke-kernel-migration-check/display-handoff734
test "$(cat "$display_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE214})"
cmp "$display_proof/SHA256SUMS" display-full7345/display-handoff734/SHA256SUMS
jq -e '.compiler_modes==4 and .actual_arm64_provider_objects==1 and .firmware_rcg_configuration_preserved and .normal_park_restore_retained and .semantic_mutants==2' "$display_proof/qualification.json"
bash display-full7345/display-handoff734/tests/native-display-handoff734.sh "$PWD" "$super_objects"
sha256sum -c --strict --quiet "$display_proof/source.sha256"
# UKE_DISPLAY_FULL7345_BUILD_END
# UKE_CAMERA_FULL7346_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE217})" %{SOURCE216} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native22-proof
(cd native-generated/camera-native22-proof;rpm2cpio %{SOURCE216} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
camera_proof=$PWD/native-generated/camera-native22-proof/usr/share/uke-kernel-migration-check/camera-owner734
test "$(cat "$camera_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE217})"
cmp "$camera_proof/SHA256SUMS" camera-full7346/camera-owner734/SHA256SUMS
jq -e '.schema_version==2 and .owner_compiler_modes==4 and .rom_compiler_modes==4 and .startup_compiler_modes==4 and .floor_compiler_modes==4 and .composition_compiler_modes==4 and .actual_caller_compiler_modes==4 and .semantic_mutants==7 and .actual_arm64_objects==2 and .inherited_AP0_preserved_until_sync and .all8_IRQ_enable_failures_covered and .firmware_guard_retained and .probe_calls_owner and .probe_calls_rom and .probe_calls_startup and .probe_calls_floor and .primary_CRM_command_map and .separate_CRMC_ROM_map and (.physical_camera_accepted|not) and (.contains_kernel_image|not)' "$camera_proof/qualification.json"
bash camera-full7346/camera-owner734/tests/native-camera-owner734.sh "$PWD" "$super_objects"
cmp "$camera_proof/qualification.json" camera-owner734-result/qualification.json
sha256sum -c --strict --quiet "$camera_proof/source.sha256"
camera_full5_parent=$(bash camera-full7346/camera-full5-legacy-view734.sh "$PWD")
uke_hwkm_parent=$(bash camera-full7346/camera-hwkm-legacy-view7346.sh "$camera_full5_parent")
# UKE_CAMERA_FULL7346_BUILD_END
# UKE_CAMERA_FULL7347_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE220})" %{SOURCE219} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native23-proof
(cd native-generated/camera-native23-proof;rpm2cpio %{SOURCE219} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
rom_proof=$PWD/native-generated/camera-native23-proof/usr/share/uke-kernel-migration-check/camera-rom-report734
rom_layer=$PWD/camera-full7347/camera-rom-report734
test "$(cat "$rom_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE220})"
cmp "$rom_proof/SHA256SUMS" "$rom_layer/SHA256SUMS"
jq -e '.schema_version==1 and .reporter_modes==4 and .production_admission_modes==4 and .actual_arm64_objects==2 and .maximum_lines_per_failure==23 and .hardware_reads_added==0 and .hardware_writes_added==0 and .errno_preserved and .cached_input_unchanged and .invalid_counts_refused and .firmware_guard_retained and (.physical_camera_accepted|not)' "$rom_proof/qualification.json"
bash "$rom_layer/tests/native-camera-rom-report734.sh" "$PWD" "$super_objects" "$rom_layer" "$PWD/camera-rom-report734-result"
cmp "$rom_proof/qualification.json" camera-rom-report734-result/qualification.json
sha256sum -c --strict --quiet "$rom_proof/source.sha256"
bash camera-full7347/seal-camera-rom-report7347.sh "$PWD" "$PWD/camera-rom-report734-result"
# UKE_CAMERA_FULL7347_BUILD_END
# UKE_CAMERA_FULL7348_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE223})" %{SOURCE222} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native26-proof
(cd native-generated/camera-native26-proof;rpm2cpio %{SOURCE222} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
native_proof25=$PWD/native-generated/camera-native26-proof/usr/share/uke-kernel-migration-check
for pair in odd parent;do
 case "$pair" in
  odd) name=camera-odd734;source_commit=$(jq -er .odd.source_commit %{SOURCE223});;
  parent) name=camera-parent734;source_commit=$(jq -er .native.source_commit %{SOURCE223});;
 esac
 proof=$native_proof25/$name
 layer=$PWD/camera-full7348/$name
 test "$(cat "$proof/source-commit")" = "$source_commit"
 cmp "$proof/SHA256SUMS" "$layer/SHA256SUMS"
 if test "$pair" = odd;then
  jq -e '.compiler_modes==4 and .before_controls==2 and .actual_arm64_objects==2 and .unknown_shifts_refused and .voltage_limits_unchanged and .firmware_ownership_retained and (.physical_camera_accepted|not)' "$proof/qualification.json"
 else
  jq -e '.constructor_modes==4 and .actual_pll_and_caller_modes==4 and .passive_modes==4 and .passive_semantic_mutants==4 and .before_controls==2 and .actual_arm64_objects==2 and .firmware_plls_unchanged and .original_limits_and_guards_retained and (.physical_camera_accepted|not)' "$proof/qualification.json"
 fi
 bash "$layer/tests/native-camera-$pair"'734.sh' "$PWD" "$super_objects" "$layer" "$PWD/camera-$pair"'734-result'
 cmp "$proof/qualification.json" "camera-$pair"'734-result/qualification.json'
 sha256sum -c --strict --quiet "$proof/source.sha256"
done
bash camera-full7348/seal-camera-native7348.sh "$PWD"
camera_full5_parent=$(bash camera-full7348/project-camera-native7348.sh "$PWD")
# UKE_CAMERA_FULL7348_BUILD_END
# UKE_CAMERA_FULL7349_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE226})" %{SOURCE225} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native32-proof
(cd native-generated/camera-native32-proof;rpm2cpio %{SOURCE225} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
receive_proof=$PWD/native-generated/camera-native32-proof/usr/share/uke-kernel-migration-check
for name in camss-lite734 phy-power734 csid-irq734 csid-stream734;do
 layer=$PWD/camera-full7349/$name
 proof=$receive_proof/$name
 test "$(cat "$layer/source-commit")" = "$(jq -er --arg name "$name" '.qualified_layers[]|select(.name==$name)|.source_commit' %{SOURCE226})"
 cmp "$proof/source-commit" "$layer/source-commit"
 cmp "$proof/SHA256SUMS" "$layer/SHA256SUMS"
 case "$name" in
  camss-lite734) script=native-camss-lite734.sh;;
  phy-power734) script=native-phy-power734.sh;;
  csid-irq734) script=native-csid-irq734.sh;;
  csid-stream734) script=native-csid-stream734.sh;;
 esac
 bash "$layer/tests/$script" "$PWD" "$super_objects" "$layer" "$PWD/$name-result"
 cmp "$proof/qualification.json" "$name-result/qualification.json"
 sha256sum -c --strict --quiet "$proof/source.sha256"
done
bash camera-full7349/tests/native-front-eeprom734.sh "$PWD" "$super_objects" "$PWD/camera-full7349" "$PWD/front-eeprom734-result"
bash camera-full7349/seal-camera-full7349.sh "$PWD"
# UKE_CAMERA_FULL7349_BUILD_END
# UKE_CAMERA_FULL73410_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE229})" %{SOURCE228} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native33-proof
(cd native-generated/camera-native33-proof;rpm2cpio %{SOURCE228} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
front_proof=$PWD/native-generated/camera-native33-proof/usr/share/uke-kernel-migration-check/front-stage734
test "$(cat "$front_proof/source-commit")" = "$(jq -er .native.source_commit %{SOURCE229})"
bash camera-full73410/tests/native-camera-full73410.sh "$PWD" "$super_objects" "$PWD/camera-full73410" "$front_proof"
# UKE_CAMERA_FULL73410_BUILD_END
# UKE_CAMERA_ICC_HF_FULL734_BUILD_BEGIN
printf '%s  %s\n' f21e4d0383eb36ffc9e5c25f89bcb24eedf2fff713822255064366f94515322c %{SOURCE230} | sha256sum -c --strict --quiet -
printf '%s  %s\n' 7f6fc3dc2fdf3d34a7f7a428a41ee475830e2b7e97269de8c8e21e7da003e57f %{SOURCE231} | sha256sum -c --strict --quiet -
tar -xJf %{SOURCE230}
icc_layer=$PWD/camera-icc-hf734
(cd "$icc_layer"; sha256sum -c --strict --quiet SHA256SUMS)
mkdir native-generated/camera-icc-hf-native34-proof
(cd native-generated/camera-icc-hf-native34-proof; rpm2cpio %{SOURCE231} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
icc_proof=$PWD/native-generated/camera-icc-hf-native34-proof/usr/share/uke-kernel-migration-check/camera-icc-hf734
grep -Fxq 9bdafb92d5189ba834b606c84d7c8ec59e844101 "$icc_proof/source-commit"
cmp "$icc_proof/source-commit" "$icc_layer/source-commit"
cmp "$icc_proof/SHA256SUMS" "$icc_layer/SHA256SUMS"
for file in pre.sha256 post.sha256 icc.patch; do
    cmp "$icc_proof/$file" "$icc_layer/src/camera/icc-hf734/$file"
done
bash "$icc_layer/tests/native-camera-icc-hf734.sh" "$PWD" "$super_objects" "$icc_layer" "$PWD/camera-icc-hf734-result"
cmp "$icc_proof/qualification.json" camera-icc-hf734-result/qualification.json
cmp "$icc_proof/source.sha256" camera-icc-hf734-result/source.sha256
sha256sum -c --strict --quiet camera-icc-hf734-result/source.sha256
# UKE_CAMERA_ICC_HF_FULL734_BUILD_END
# UKE_GUNYAH_WATCHDOG_FULL734_BUILD_BEGIN
(
printf '%s  %s\n' c07e80a3e33a5e5be0ee06bf5f38f700e211c1f37d305cb49d82c16b23ef7856 %{SOURCE235} | sha256sum -c --strict --quiet -
printf '%s  %s\n' f5fee5cc98b9ee0b1d0e1b93f42aa12f1893fd38e6b705aaf384089bea0ab610 %{SOURCE236} | sha256sum -c --strict --quiet -
evidence=$PWD/native-generated/gunyah-watchdog734
mkdir -p "$evidence/proof"
tar -xJf %{SOURCE235} -C "$evidence"
layer=$evidence/gunyah-watchdog-source
(cd "$layer"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$evidence/proof"; rpm2cpio %{SOURCE236} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
receipt=$evidence/proof/usr/share/uke-gunyah-watchdog-source-check
cmp "$receipt/SHA256SUMS" "$layer/SHA256SUMS"
for name in pre resume post; do
    cmp "$receipt/$name.sha256" "$layer/layer/$name.sha256"
done
jq -e '.architecture=="aarch64" and .compiler_modes==2 and .actual_driver_callbacks and
    .actual_core_timeout_and_worker and .software_deadline_seconds==600 and .hardware_limit_ms==32000 and
    .upstream_resume_backport and (.physical_watchdog_reset_verified|not)' "$receipt/qualification.json" >/dev/null
for file in drivers/watchdog/watchdog_dev.c include/linux/watchdog.h; do
    cmp "$file" "$layer/kernel/$file"
done
bash "$layer/layer/apply.sh" "$PWD"
for compiler in gcc clang; do
    CC="$compiler" bash "$layer/gunyah-watchdog-heartbeat734.sh" "$PWD"
done
grep -Fxq 'CONFIG_GUNYAH_WATCHDOG=y' "$super_objects/.config"
make -s O="$super_objects" ARCH=arm64 LLVM=1 LLVM_IAS=1 drivers/watchdog/gunyah_wdt.o
llvm-readelf -h "$super_objects/drivers/watchdog/gunyah_wdt.o" | grep -F AArch64
sha256sum -c --strict --quiet "$receipt/post.sha256"
)
# UKE_GUNYAH_WATCHDOG_FULL734_BUILD_END
# UKE_SPEAKER_RGB_FULL734_BUILD_BEGIN
(
printf '%s  %s\n' \
    9d3144c4725a56f07bd24621975f51c33210d2409b0972966635350be2e7fce8 %{SOURCE237} \
    2be7d526ab05b19c58d01c278941e899af47893d452f36e4c9b14950889ca831 %{SOURCE238} \
    06ff5e77997bb9c8036191a71aa97544b0c8e297b831d8ab99913f461b96c7b8 %{SOURCE239} \
    | sha256sum -c --strict --quiet -
stage=$PWD/native-generated/speaker-rgb-input734
mkdir "$stage"
tar -xJf %{SOURCE237} -C "$stage"
layer=$stage/uke-speaker-rgb-source
(cd "$layer"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$layer/rgb"; sha256sum -c --strict --quiet SHA256SUMS)
rpm2cpio %{SOURCE239} | cpio --quiet -i --to-stdout '*/uke-rgb-pattern-source-check/SHA256SUMS' | cmp - "$layer/rgb/SHA256SUMS"
rpm2cpio %{SOURCE239} | cpio --quiet -i --to-stdout '*/uke-rgb-pattern-source-check/qualification.txt' > "$stage/rgb-proof.txt"
test "$(grep -c '^Stable full reports issue no USB online requests' "$stage/rgb-proof.txt")" = 2
rpm2cpio %{SOURCE238} | cpio --quiet -i --to-stdout '*/uke-fs19xx-stop-reset-source-check/qualification.txt' > "$stage/speaker-proof.txt"
test "$(grep -c '^candidate: eight STOP cases passed; first failed write uses 1 bus request' "$stage/speaker-proof.txt")" = 2
awk '$2=="check-stop-reset.sh" || $2=="0032-fs19xx-stop-reset-on-bus-error.patch" { print; n++ } END { if (n!=2) exit 1 }' "$stage/speaker-proof.txt" > "$stage/speaker-sources.sha256"
(cd "$layer"; sha256sum -c --strict --quiet "$stage/speaker-sources.sha256")
bash "$layer/apply-speaker-rgb-full734.sh" "$PWD" "$layer" source
for compiler in gcc clang; do
    CC="$compiler" bash "$layer/check-stop-reset.sh" sound/soc/codecs/fs19xx.c candidate
    CC="$compiler" bash "$layer/rgb/tests/rgb-charge-events.sh"
done
grep -Fxq 'CONFIG_SND_SOC_FS19XX=m' "$super_objects/.config"
grep -Fxq 'CONFIG_LEDS_UKE_RGB=m' "$super_objects/.config"
make -s O="$super_objects" ARCH=arm64 LLVM=1 LLVM_IAS=1 sound/soc/codecs/fs19xx.o drivers/leds/leds-uke-rgb.o
for object in sound/soc/codecs/fs19xx drivers/leds/leds-uke-rgb; do
    llvm-readelf -h "$super_objects/$object.o" | grep -F AArch64
done
)
# UKE_SPEAKER_RGB_FULL734_BUILD_END
# UKE_FS19XX_TELEMETRY734_BUILD_BEGIN
(
printf '%s  %s\n' \
    012d6dd91d44387f152d64c6e97fd225a14588bcf3b327461041e2e375e8b7e0 %{SOURCE243} \
    ebed70323d6d9d02744645ef6c2dd6d7019747ca51a835ab55e55d648a946269 %{SOURCE244} |
    sha256sum -c --strict --quiet -
rpm2cpio %{SOURCE243} | cpio --quiet -i --to-stdout './usr/share/uke-early-plymouth-source-check/fs19xx-coil.json' |
    jq -e '.architecture=="aarch64" and .parent_prelink==11348679 and
        .callback_fixtures==11349735 and .actual_coil_object and .actual_apm_composite and
        .restore_exact and (.linked_kernel_image|not) and (.live_read|not)' >/dev/null
bash %{SOURCE244} "$PWD" source %{SOURCE240} %{SOURCE241} %{SOURCE242}
bash %{SOURCE261} "$PWD" runtime %{SOURCE259} %{SOURCE260}
)
# UKE_FS19XX_TELEMETRY734_BUILD_END
# The historical native receipt checks the original Iris source before this layer.
# UKE_IRIS_DMA_FLOOR735_BUILD_BEGIN
iris_source=drivers/media/platform/qcom/iris/iris_probe.c
iris_origin=$(awk -v file="$iris_source" '$2==file {print $1; n++} END {if(n!=1)exit 1}' "$native_proof/source.sha256")
printf '%s  %s\n' "$iris_origin" "$iris_source" | sha256sum -c --strict --quiet -
git apply --check --whitespace=error %{SOURCE263}
git apply --whitespace=error %{SOURCE263}
git apply --reverse --check --whitespace=error %{SOURCE263}
# UKE_IRIS_DMA_FLOOR735_BUILD_END
# UKE_TOUCH_UCSI_LAYERS735_BUILD_BEGIN
printf '%s  %s\n' d6922466da05b96bfc8d0a00f2939b274bf2c7aab6d217488b8ea249c8f79e0e %{SOURCE264} | sha256sum -c --strict --quiet -
printf '%s  %s\n' 5273901d163df47390404e24dbe5bde99bc63e9e6fbf2fff477dcbf805c730a9 %{SOURCE265} | sha256sum -c --strict --quiet -
printf '%s  %s\n' 519d5537b82179a2c03bf2a52f6afbf646aca1668e0eb9c4140c59e398d16406 %{SOURCE266} | sha256sum -c --strict --quiet -
mkdir native-generated/touch-ucsi735
(cd native-generated/touch-ucsi735; tar -xJf %{SOURCE264})
rpm2cpio %{SOURCE265} | cpio -i --quiet --to-stdout './usr/share/uke-vi-tdm-wire-check/results.txt' > native-generated/touch-ucsi735/touch-proof.txt
rpm2cpio %{SOURCE266} | cpio -i --quiet --to-stdout './usr/share/uke-source-checks/ucsi-735.txt' > native-generated/touch-ucsi735/ucsi-proof.txt
test "$(grep -c '^Actual touch fallback:' native-generated/touch-ucsi735/touch-proof.txt)" = 4
test "$(grep -c '^UCSI partner PD registration:' native-generated/touch-ucsi735/ucsi-proof.txt)" = 4
bash native-generated/touch-ucsi735/overlay/check-layer.sh "$PWD" source native-generated/ucsi7353/prepared.sha256
# UKE_TOUCH_UCSI_LAYERS735_BUILD_END
# Validate the signed scenario proof and build the final packaged topology.
printf '%s  %s\n' 5fa724ea9cfaf9470c5c80c5e06ad8572a8380d5487d4e7ff0b4f7da6a9efb19 %{SOURCE267} | sha256sum -c --strict --quiet -
printf '%s  %s\n' 99fc0bcd5355538e2f3b13f83c2e185a6d0bae8d09510c29d846826b5ac29b13 %{SOURCE268} | sha256sum -c --strict --quiet -
printf '%s  %s\n' ec4c40b16c87cc3f5ce7538159d5cda2933af2d7e4436301ef73b495a4dd6fea %{SOURCE269} | sha256sum -c --strict --quiet -
(cd native-generated; tar -xJf %{SOURCE268})
(cd native-generated/scenario-layer; sha256sum -c --strict --quiet SHA256SUMS)
rpm2cpio %{SOURCE267} | cpio -i --quiet --to-stdout './usr/share/uke-vi-tdm-wire-check/results.txt' > native-generated/scenario-layer/proof.txt
grep -Fx 'Compiled topology: graph 40 speaker and VI use DONT_CARE; all other bytes match.' native-generated/scenario-layer/proof.txt
test "$(grep -c '^Protected device scenario admission tests passed with ' native-generated/scenario-layer/proof.txt)" = 2
bash native-generated/scenario-layer/apply.sh "$PWD" apply
# Apply the demand-only readback after the historical source qualification.
feedback_stage=$PWD/native-generated/fs19xx-feedback735
feedback_codec=sound/soc/codecs/fs19xx.c
mkdir "$feedback_stage"
printf '%s  %s\n' \
  f3362beee71fa34a81b29d19e3314dd913039c27438fdb0c89b8afdd57666cc7 %{SOURCE270} \
  9000e0e5bc48ba24bfd1d5ccb08a31cf6bb3b8ecbb9b8fb54ad4cf0745eaeb00 %{SOURCE271} \
  5e698ae9bd69103885d410f0575301acbb00381a43b12e3fad694b2f18f6893e %{SOURCE272} \
  b85984dd3b06d4ae83dd3499b8372b7924209462c37a9017e868d441917b2927 "$feedback_codec" |
  sha256sum -c --strict --quiet -
rpm2cpio %{SOURCE272} | cpio -i --quiet --to-stdout './usr/share/uke-fs19xx-stop-reset-source-check/qualification.txt' > "$feedback_stage/proof.txt"
test "$(grep -Fxc 'FS19xx converter status: four flags, idle with no bus reads, permissions and two bus failures passed.' "$feedback_stage/proof.txt")" = 4
grep -Fx 'f3362beee71fa34a81b29d19e3314dd913039c27438fdb0c89b8afdd57666cc7  0039-fs19xx-read-feedback-converter-status.patch' "$feedback_stage/proof.txt"
grep -Fx '9000e0e5bc48ba24bfd1d5ccb08a31cf6bb3b8ecbb9b8fb54ad4cf0745eaeb00  audio-fs19xx-feedback-status.sh' "$feedback_stage/proof.txt"
cp -p "$feedback_codec" "$feedback_stage/parent.c"
git apply --check --whitespace=error %{SOURCE270}
git apply --whitespace=error %{SOURCE270}
printf '%s  %s\n' 6a3a88d307a91f89ad90c0a0e61c45bd3f2392f854bfc9ac38d045a576334bf1 "$feedback_codec" |
  sha256sum -c --strict --quiet -
# Keep the coldplug patch behind the existing native source proof.
battery_stage=$PWD/native-generated/battery-coldplug735
battery_source=drivers/power/supply/qcom_battmgr.c
mkdir -p "$battery_stage"
rpm2cpio %{SOURCE274} | cpio -i --quiet --to-stdout './usr/share/uke-upower-refresh-source-check/qualification.txt' > "$battery_stage/qualification.txt"
test "$(grep -Fxc 'Uke battery coldplug: limit, wrap, signal, teardown, firmware loss and unrelated reads passed.' "$battery_stage/qualification.txt")" = 4
printf '%s  %s\n' 63b0832264ac851cd7eff35f9c0f36ddb45fa36d24562375cb0684c640c0420c "$battery_source" | sha256sum -c --strict --quiet -
cp -p "$battery_source" "$battery_stage/parent.c"
git apply --check --whitespace=error %{SOURCE273}
git apply --whitespace=error %{SOURCE273}
printf '%s  %s\n' 41298b1d3f925e8d59f21fe3dbb2243c7e582641b53e886404397fcf6934be50 "$battery_source" | sha256sum -c --strict --quiet -
# Keep the new runtime layers behind their exact signed source checks.
followup=$PWD/native-generated/uke-audio-charge735
apm_source=sound/soc/qcom/qdsp6/q6apm.c
mkdir -p "$followup"
rpm2cpio %{SOURCE276} | cpio -i --quiet --to-stdout './usr/share/uke-vi-tdm-wire-check/results.txt' > "$followup/vi.txt"
rpm2cpio %{SOURCE278} | cpio -i --quiet --to-stdout './usr/share/uke-vi-tdm-wire-check/results.txt' > "$followup/gain.txt"
rpm2cpio %{SOURCE280} | cpio -i --quiet --to-stdout './usr/share/uke-upower-refresh-source-check/qualification.txt' > "$followup/charge.txt"
test "$(grep -Fc 'Feedback START: exact subgraph lists, acknowledged order, faults, and ordinary graphs passed.' "$followup/vi.txt")" = 4
test "$(grep -Fc 'Default policy: effective 223 limit and refusal of 243 passed.' "$followup/gain.txt")" = 4
test "$(grep -Fc 'Qualified Uke: OEM 243 limit and protected register writer passed.' "$followup/gain.txt")" = 4
test "$(grep -Fc 'Fixed OEM charger reads: privilege, wire identity, epoch and write refusal passed.' "$followup/charge.txt")" = 4
for file in %{SOURCE275} %{SOURCE277} %{SOURCE279}; do
    digest=$(sha256sum "$file" | cut -d' ' -f1)
    test "$(grep -lFx "$digest  ${file##*/}" "$followup/"*.txt | wc -l)" = 1
done
sha256sum -c --strict --quiet - <<'FOLLOWUP_SHA256'
ca0c21c51dfc756a9ec22aec94790e5faa005b682c99a49a43c983de8cab0709  sound/soc/qcom/qdsp6/q6apm.c
6a3a88d307a91f89ad90c0a0e61c45bd3f2392f854bfc9ac38d045a576334bf1  sound/soc/codecs/fs19xx.c
41298b1d3f925e8d59f21fe3dbb2243c7e582641b53e886404397fcf6934be50  drivers/power/supply/qcom_battmgr.c
FOLLOWUP_SHA256
cp -p "$apm_source" "$followup/q6apm-parent.c"
cp -p "$feedback_codec" "$followup/fs19xx-parent.c"
cp -p "$battery_source" "$followup/battmgr-parent.c"
for file in %{SOURCE275} %{SOURCE277} %{SOURCE279}; do
    git apply --exclude='*/Kconfig' --check --whitespace=error "$file"
    git apply --exclude='*/Kconfig' --whitespace=error "$file"
done
# Keep the two separately signed native battery checks tied to the production inputs.
printf '%s  %s\n' d198f0d5f07ddfd37854112e45ed336ba67ec2f680fd4557a5b0b582345453d1 %{SOURCE283} \
    545617dd27d40cb417073ce59093b26d83a5c9e3a5f1230767d392ccf6b8321e %{SOURCE285} |
    sha256sum -c --strict --quiet -
rpm2cpio %{SOURCE283} | cpio -i --quiet --to-stdout './usr/share/uke-upower-refresh-source-check/qualification.txt' > "$followup/usb-class.txt"
rpm2cpio %{SOURCE285} | cpio -i --quiet --to-stdout './usr/share/uke-upower-refresh-source-check/qualification.txt' > "$followup/battery-publication.txt"
test "$(grep -Fxc 'OEM USB status: privilege, namespace, legacy adapter cache and epoch passed.' "$followup/usb-class.txt")" = 4
test "$(grep -Fxc 'Battery publication: readiness, confirmed absence, epoch changes, retry and cleanup passed.' "$followup/battery-publication.txt")" = 8
grep -Fx '3cd42753bca531099ccbf2de943201ebbf769cf9e8d06dac5b5a18b73d97d4c2  0005-uke-qcom-battmgr-observe-fitted-usb-source-class.patch' "$followup/usb-class.txt"
grep -Fx 'a0cb81d05f7596af2c41931c60ebc3441b7f9a12c83b094824c8cce344b5188c  0007-uke-qcom-battmgr-publish-after-firmware-identity.patch' "$followup/battery-publication.txt"
printf '%s  %s\n' 3cd42753bca531099ccbf2de943201ebbf769cf9e8d06dac5b5a18b73d97d4c2 %{SOURCE282} \
  a0cb81d05f7596af2c41931c60ebc3441b7f9a12c83b094824c8cce344b5188c %{SOURCE284} \
  e32067a067cff6f1b75b6e7056ce62250b565bb839b3353757ab85a30c78fec9 "$battery_source" | sha256sum -c --strict --quiet -
git apply --check --whitespace=error %{SOURCE282}
git apply --whitespace=error %{SOURCE282}
printf '%s  %s\n' 1a2dae2f3bc6b7ee3e510994c14a540e01c3ab4b47fbd66bbea9d82175896daf "$battery_source" | sha256sum -c --strict --quiet -
git apply --exclude='*/Kconfig' --check --whitespace=error %{SOURCE284}
git apply --exclude='*/Kconfig' --whitespace=error %{SOURCE284}
printf '%s  %s\n' 9f4e6e43720d1791d1c55f2824061fc3a1233a124f72ec03e209908704b15ff5 "$battery_source" | sha256sum -c --strict --quiet -
# Admit the fixed adapter ID, SVID and three OEM modes through the existing GET-only path.
printf '%s  %s\n' 4390ed2101da77f55a145ebce85935e299394a1fcbaa911ef85b6dfec8622b82 %{SOURCE287} \
    eab0dc5d349abf07ce8a20b49bda013398c195396bcf397d4639015ddb42fe57 %{SOURCE288} | sha256sum -c --strict --quiet -
rpm2cpio %{SOURCE288} | cpio -i --quiet --to-stdout './usr/share/uke-upower-refresh-source-check/qualification.txt' > "$followup/charge-modes.txt"
test "$(grep -Fxc 'Fixed OEM charger and mode reads: privilege, wire identity, epoch and write refusal passed.' "$followup/charge-modes.txt")" = 4
grep -Fx '4390ed2101da77f55a145ebce85935e299394a1fcbaa911ef85b6dfec8622b82  0008-uke-qcom-battmgr-observe-fitted-charge-modes.patch' "$followup/charge-modes.txt"
git apply --check --whitespace=error %{SOURCE287}
git apply --whitespace=error %{SOURCE287}
printf '%s  %s\n' 7c457f6d35628502601a4c98041321bac49fe95ac80555ca554b0f377c557e55 "$battery_source" | sha256sum -c --strict --quiet -
# Admit the signed checks for source PDO discovery and fast-charge diagnostics.
printf '%s  %s\n' b7734587dbd5a2accbee2f0f7c1d7e7dfc2b520e9f1eeb8a921129b9e6f1ee52 %{SOURCE290} \
    d6de2e29022ee451831268b36a465a6979d6f51a268dd67bcde4213f910fd18b %{SOURCE291} \
    13d8d789fa04507c72ec25f0a07e5f0a3ec0ed02d3254e96e8ff6ad9eb6aaf54 %{SOURCE292} \
    1c3e704abdd54e304bd767d8a9e9cf384d6a2089275af63e278380d8f127eb60 %{SOURCE293} | sha256sum -c --strict --quiet -
rpm2cpio %{SOURCE291} | cpio -i --quiet --to-stdout './usr/share/uke-source-checks/ucsi-pdo-discovery.txt' > "$followup/pd-source-details.txt"
rpm2cpio %{SOURCE293} | cpio -i --quiet --to-stdout './usr/share/uke-upower-refresh-source-check/qualification.txt' > "$followup/fast-charge-status.txt"
test "$(grep -Fxc 'PDO discovery reports capability, current replies and invalidation without new firmware calls' "$followup/pd-source-details.txt")" = 2
test "$(grep -Fxc 'Fixed OEM charger and mode reads: privilege, wire identity, epoch and write refusal passed.' "$followup/fast-charge-status.txt")" = 4
printf '%s  %s\n' \
    0c18fdc5d25bbdb7ae270bc703e6a7c7a43b1463bc754a28ce2232517c263dc9 drivers/usb/typec/ucsi/psy.c \
    e8f90cc3fcd1f3b4111150b245b711fd540d23a51751d53080adfaa6db16f60f drivers/usb/typec/ucsi/ucsi.c \
    7308c1acb8c7545ed75db35c7caee94d454611e65250a4d0ce390aaeb434ee7f drivers/usb/typec/ucsi/ucsi.h \
    | sha256sum -c --strict --quiet -
for file in %{SOURCE290} %{SOURCE292}; do
    git apply --check --whitespace=error "$file"
    git apply --whitespace=error "$file"
done
printf '%s  %s\n' 6a2468f8da558d1e9cf2308c23b8dbbe12a6cfbd1409a3e6ee72a11bfb7a03c8 "$battery_source" | sha256sum -c --strict --quiet -
printf '%s  %s\n' ce583356a12114b509bdb36b2f2aa5e7de270638dcd8eda9e5097dc76d5cd97d Documentation/ABI/testing/sysfs-driver-ucsi-uke-contract | sha256sum -c --strict --quiet -
sha256sum drivers/usb/typec/ucsi/{psy.c,ucsi.c,ucsi.h} > "$followup/linked-ucsi-observer.sha256"
# Admit the signed Uke fixed-PDO reporting check after the historical cache layer.
ucsi_fixed_assets=$PWD/native-generated/normal-ucsi-fixed-assets
printf '%%s  %%s\n' 51a999c7fec2ed0782fbae29018289cbae0105b35cf2baff35683883a7291564 %{SOURCE403} | sha256sum -c --strict --quiet -
mkdir "$ucsi_fixed_assets"
tar -xJf %{SOURCE403} -C "$ucsi_fixed_assets"
(cd "$ucsi_fixed_assets"; sha256sum -c --strict --quiet SHA256SUMS)
rpm2cpio "$ucsi_fixed_assets/uke-ucsi-contract-735-check-0.1-8.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-source-checks/ucsi-pdo-discovery.txt > "$followup/ucsi-fixed-contract.txt"
test "$(grep -Fxc 'Uke current and voltage require coherent fixed PD; raw contract and generic paths retained' "$followup/ucsi-fixed-contract.txt")" = 4
ucsi_now_file=drivers/usb/typec/ucsi/psy.c
ucsi_now_patch=$ucsi_fixed_assets/0131-uke-ucsi-require-coherent-fixed-contract-for-now.patch
printf '%%s  %%s\n' c9ac7e527371b52f1f26d3a6fd46e500be4bb3086f9e0efba1551e307294ceab "$ucsi_now_patch" bbe4d0cbab6e7c6de0d519bc720428fefeec5b540ab124f47e8e602b5176702a "$ucsi_now_file" | sha256sum -c --strict --quiet -
git apply --check --whitespace=error "$ucsi_now_patch"
git apply --whitespace=error "$ucsi_now_patch"
grep -Fx 'b9f5cb832ab77f95a5702de3424d5b575aa3e3103283a63143d8d7e1ab4a41f3  drivers/usb/typec/ucsi/psy.c' "$followup/ucsi-fixed-contract.txt"
printf '%%s  %%s\n' b9f5cb832ab77f95a5702de3424d5b575aa3e3103283a63143d8d7e1ab4a41f3 "$ucsi_now_file" | sha256sum -c --strict --quiet -
sha256sum drivers/power/supply/Kconfig > "$followup/linked-charge-config.sha256"
# Confirm that the signed fixture tested the exact codec preimage and correction.
alsa_state_proof="$followup/alsa-state.txt"
rpm2cpio %{SOURCE295} | cpio -i --quiet --to-stdout './usr/share/uke-source-checks/fs19xx-alsa-state.txt' > "$alsa_state_proof"
test "$(grep -Fxc 'FS19xx converter status: four flags, restricted and idle reads without bus access, two bus failures passed.' "$alsa_state_proof")" = 4
grep -Fx '3495370e97bf4ceef5e3907b264c182e8dcbda38ca724ff758311672c9e61ca2  fs19xx-full73511.c' "$alsa_state_proof"
grep -Fx '36d471fb4c6f9335f1b94d6b4964ea6e48d885724d78323e9817851c383e59b2  0042-fs19xx-preserve-alsa-state-on-restricted-read.patch' "$alsa_state_proof"
grep -Fx 'efb4d2fbcd3f3687cfb2f7900a0f26d9b743020565192b63d7d1196b3da2d2ca  audio-fs19xx-feedback-status.sh' "$alsa_state_proof"
printf '%s  %s\n' 3495370e97bf4ceef5e3907b264c182e8dcbda38ca724ff758311672c9e61ca2 "$feedback_codec" \
    36d471fb4c6f9335f1b94d6b4964ea6e48d885724d78323e9817851c383e59b2 %{SOURCE294} |
  sha256sum -c --strict --quiet -
git apply --check --whitespace=error %{SOURCE294}
git apply --whitespace=error %{SOURCE294}
printf '%s  %s\n' 0e1f93f9d22cd87f82d0ae46d2ff5f22cb6bf9e386c0398c10f03d74bac28500 "$feedback_codec" |
  sha256sum -c --strict --quiet -
sha256sum "$apm_source" "$feedback_codec" "$battery_source" > "$followup/linked-source.sha256"
# Match the event patch to the signed DT, behavior and object proofs.
printf '%s  %s\n' 998a943dec14ac8cc5546e4c55957bb252bbc6da24f9e3bfbbf0f3cd58275424 %{SOURCE296} 0ae9ed52cddcf9c946f24d4b907f0102b431a7c344cdcb60b518738a27b81b51 %{SOURCE297} 689cfe3de47413bca02ed0a7387f2b8dbbe2044a08228f5913bb74993c8dcea2 %{SOURCE298} 8117fdbc4a9aca832044603cfee869611e231f586763138c51526f1e80102bd7 %{SOURCE299} | sha256sum -c --strict --quiet -
for entry in '%{SOURCE297}|charge-screen-dt' '%{SOURCE298}|o82-charge-screen' '%{SOURCE299}|o82-charge-screen-object'; do
    file=${entry%%|*}
    report=${entry#*|}
    rpm2cpio "$file" | cpio -i --quiet --to-stdout "./usr/share/uke-source-checks/$report.txt" > "$followup/$report.txt"
done
grep -Fx 'O82 DT generation: distinct supplier identities, shared native/video graph and both embedded overlays passed' "$followup/charge-screen-dt.txt"
test "$(grep -Fxc 'O82 charge screen: exact selection, late subscriber, deduplication, blank/unblank and teardown passed.' "$followup/o82-charge-screen.txt")" = 4
test "$(grep -cE 'Machine:[[:space:]]+AArch64$' "$followup/o82-charge-screen-object.txt")" = 3
grep -Fx 'Native DRM archive exports panel events to both independent ARM64 module objects.' "$followup/o82-charge-screen-object.txt"
dt_source_hashes="$followup/charge-screen-dt.sha256"
grep -E '  \./(src/display/sm7675-uke-native-display\.dtso|tests/o82-variants-dt-contract\.sh)$' "$followup/charge-screen-dt.txt" > "$dt_source_hashes"
test "$(wc -l < "$dt_source_hashes")" = 2
for tree in native-profile boot-recipe; do
    (cd "$tree"; sha256sum -c --strict "$dt_source_hashes")
done
sed -n '2,4p' "$followup/o82-charge-screen.txt" > "$followup/charge-screen-preimage.sha256"
sed -n '5,10p' "$followup/o82-charge-screen.txt" > "$followup/charge-screen-prepared.sha256"
sha256sum -c --strict --quiet "$followup/charge-screen-preimage.sha256"
git apply --check --whitespace=error %{SOURCE296}
git apply --whitespace=error %{SOURCE296}
sha256sum -c --strict --quiet "$followup/charge-screen-prepared.sha256"
bash %{SOURCE397} linked %{SOURCE396}
export SENEMOS_PUBLICATION_ABI='%{krel}'
# Apply the signed R13-compatible gain-223 VI diagnostic layer only.
vi_assets=$PWD/native-generated/normal-vi-assets
vi_layer=$PWD/native-generated/normal-vi-linked
printf '%%s  %%s\n' b8e5f7f4e475f2d70ca3e0ab01883249dc471daee5eb670a04edd15d2510a46f %{SOURCE399} | sha256sum -c --strict --quiet -
mkdir "$vi_assets"
tar -xJf %{SOURCE399} -C "$vi_assets"
(cd "$vi_assets"; sha256sum -c --strict --quiet SHA256SUMS)
bash "$vi_assets/vi-layer.sh" prepare "$PWD" "$vi_layer"
# Fixed, read-only FourSemi BSG monitor; retain the gain-223 guard.
bsg_assets=$PWD/native-generated/normal-bsg-monitor
printf '%%s  %%s\n' 5837ce0c5a8902de2bae42a09e34f942c9b5df09afc8070b5028275b53bf810d %{SOURCE421} | sha256sum -c --strict --quiet -
mkdir "$bsg_assets"
tar -xJf %{SOURCE421} -C "$bsg_assets"
(cd "$bsg_assets"; sha256sum -c --strict --quiet SHA256SUMS)
bash "$bsg_assets/verify-prelink-proof.sh"
bash "$bsg_assets/apply-bsg-monitor735.sh" prepare "$PWD"
vi_checker=native-profile/packaging/native/check-migration-boot-config731.sh
printf '%%s  %%s\n' a6dea0ea56e0f15028910233f9ffd7a441c31ea23d2454fa682f3e3106ffd502 "$vi_checker" | sha256sum -c --strict --quiet -
cp -- "$vi_checker" "$vi_layer/migration-check-parent.sh"
install -m644 "$vi_assets/check-migration-boot-config731-vi.sh" "$vi_checker"
vi_boot=boot-recipe/src/boot/build-payload.sh
cp -- "$vi_boot" "$vi_layer/boot-payload-parent.sh"
node "$vi_assets/vi-boot-edit.mjs" "$vi_boot" - - payload
bash -n "$vi_boot"
charge_assets=$PWD/native-generated/normal-charge-assets
charge_layer=$PWD/native-generated/normal-charge-linked
printf '%%s  %%s\n' e402a1b6969008f8525947cb1e2d77efe37460673396ad3a5938213ad73c8be2 %{SOURCE400} | sha256sum -c --strict --quiet -
mkdir "$charge_assets"
tar -xJf %{SOURCE400} -C "$charge_assets"
(cd "$charge_assets"; sha256sum -c --strict --quiet SHA256SUMS)
bash "$charge_assets/normal-charge-layer.sh" prepare "$PWD" "$charge_layer"
usb_type_assets=$PWD/native-generated/normal-usb-type-assets
printf '%%s  %%s\n' 38341d486c2e5d369bcf9548b4b76f11aae34072710c4d6967a8508372c62da6 %{SOURCE402} | sha256sum -c --strict --quiet -
mkdir "$usb_type_assets"
tar -xJf %{SOURCE402} -C "$usb_type_assets"
(cd "$usb_type_assets"; sha256sum -c --strict --quiet SHA256SUMS)
usb_type_proof=$(rpm2cpio "$usb_type_assets/uke-fitted-fuel-gauge-soc-check-0.1-2.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-fitted-fuel-gauge-soc-check/qualification.txt)
usb_type_patch="$usb_type_assets/0015-uke-report-confirmed-pd-usb-type.patch"
usb_type_digest=$(sha256sum "$usb_type_patch" | cut -d ' ' -f1)
grep -Fxq "$usb_type_digest  ${usb_type_patch##*/}" <<< "$usb_type_proof"
test "$(grep -Fxc 'Actual USB type reader preserves legacy telemetry and requires a fresh online PD source.' <<< "$usb_type_proof")" = 2
usb_type_source=drivers/power/supply/qcom_battmgr.c
printf '%%s  %%s\n' 238500f7825481331b563bb95a836b639a80a4e286f663f1336d9598e9d42b51 "$usb_type_source" | sha256sum -c --strict --quiet -
git apply --check --whitespace=error "$usb_type_patch"
git apply --whitespace=error "$usb_type_patch"
printf '%%s  %%s\n' 543c51d030d267700f75941fdb60a6cc70a09ca79f043842afd4ffaa0986d0df "$usb_type_source" | sha256sum -c --strict --quiet -
CC=gcc bash "$usb_type_assets/battery-usb-type-report.sh" "$usb_type_source"
# UKE_THRESHOLD_OBSERVATION_PREPARE_BEGIN
threshold_assets=$PWD/native-generated/normal-threshold-observation-assets
printf '%%s  %%s\n' 0159e8c92f449c84cd80a18f34c76edfa4833e243d16523253920b45a43c4dac %{SOURCE404} | sha256sum -c --strict --quiet -
mkdir "$threshold_assets"
tar -xJf %{SOURCE404} -C "$threshold_assets"
(cd "$threshold_assets"; sha256sum -c --strict --quiet SHA256SUMS)
threshold_patch="$threshold_assets/0016-uke-reuse-observed-charge-threshold-pair.patch"
threshold_proof="$threshold_assets/qualification.txt"
rpm2cpio "$threshold_assets/uke-kernel-migration-check-7.3.5-6.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-kernel-migration-check/threshold-observation735/qualification.txt > "$threshold_proof"
threshold_digest=$(sha256sum "$threshold_patch" | cut -d ' ' -f1)
grep -Fxq "$threshold_digest  ${threshold_patch##*/}" "$threshold_proof"
test "$(grep -Fxc 'Baseline: 12 firmware queries for four standard threshold reads' "$threshold_proof")" = 2
test "$(grep -Fxc 'Candidate: 3 firmware queries; expiry, epochs, locks, fresh reads and partial failure passed' "$threshold_proof")" = 2
sha256sum -c --strict --quiet "$threshold_assets/before.sha256"
git apply --check --whitespace=error "$threshold_patch"
git apply --whitespace=error "$threshold_patch"
sha256sum -c --strict --quiet "$threshold_assets/after.sha256"
# UKE_THRESHOLD_OBSERVATION_PREPARE_END
# UKE_BATTERY_LIMIT_OBSERVATION_PREPARE_BEGIN
battery_limit_assets=$PWD/native-generated/normal-battery-limit-assets
printf '%%s  %%s\n' 997925be73a2539ec0b05c3cae5e7cfe01ffbabc43cb6c42cc11a4f3803816d5 %{SOURCE405} | sha256sum -c --strict --quiet -
mkdir "$battery_limit_assets"
tar -xJf %{SOURCE405} -C "$battery_limit_assets"
(cd "$battery_limit_assets"; sha256sum -c --strict --quiet SHA256SUMS)
battery_limit_patch="$battery_limit_assets/0017-uke-observe-fitted-battery-limit-replies.patch"
battery_limit_proof="$battery_limit_assets/qualification.txt"
rpm2cpio "$battery_limit_assets/uke-kernel-migration-check-7.3.5-8.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-kernel-migration-check/fitted-battery-limit735/qualification.txt > "$battery_limit_proof"
battery_limit_digest=$(sha256sum "$battery_limit_patch" | cut -d ' ' -f1)
grep -Fxq "$battery_limit_digest  ${battery_limit_patch##*/}" "$battery_limit_proof"
test "$(grep -Fxc 'Fitted BAT10/11: exact read-only envelopes, raw values, privilege and failure handling passed.' "$battery_limit_proof")" = 4
test "$(grep -Fc 'Actual Uke request matching, error, late reply, generation, PDR' "$battery_limit_proof")" = 8
sha256sum -c --strict --quiet "$battery_limit_assets/pre.sha256"
git apply --check --whitespace=error "$battery_limit_patch"
git apply --whitespace=error "$battery_limit_patch"
sha256sum -c --strict --quiet "$battery_limit_assets/post.sha256"
# UKE_BATTERY_LIMIT_OBSERVATION_PREPARE_END
# UKE_BATTERY_POWER_OBSERVATION_PREPARE_BEGIN
battery_power_patch="$battery_limit_assets/0018-uke-observe-fitted-battery-power.patch"
battery_power_proof="$battery_limit_assets/power-qualification.txt"
rpm2cpio "$battery_limit_assets/uke-kernel-migration-check-7.3.5-9.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-kernel-migration-check/fitted-battery-power735/qualification.txt > "$battery_power_proof"
battery_power_digest=$(sha256sum "$battery_power_patch" | cut -d ' ' -f1)
grep -Fxq "$battery_power_digest  ${battery_power_patch##*/}" "$battery_power_proof"
test "$(grep -Fxc 'Fitted BAT23: signed raw report, request isolation and error handling passed.' "$battery_power_proof")" = 4
test "$(grep -Fc 'Actual Uke request matching, error, late reply, generation, PDR' "$battery_power_proof")" = 8
sha256sum -c --strict --quiet "$battery_limit_assets/power-pre.sha256"
git apply --check --whitespace=error "$battery_power_patch"
git apply --whitespace=error "$battery_power_patch"
sha256sum -c --strict --quiet "$battery_limit_assets/power-post.sha256"
# UKE_BATTERY_POWER_OBSERVATION_PREPARE_END
# UKE_CHARGE_BAND_EPOCH_PREPARE_BEGIN
epoch_patch="$battery_limit_assets/0019-uke-reject-cross-epoch-charge-band-reads.patch"
epoch_proof="$battery_limit_assets/epoch-qualification.txt"
rpm2cpio "$battery_limit_assets/uke-kernel-migration-check-7.3.5-11.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-kernel-migration-check/charge-band-epoch735/qualification.txt > "$epoch_proof"
for asset in "${epoch_patch##*/}" epoch-pre.sha256 epoch-post.sha256; do
    receipt_asset=${asset#epoch-}
    digest=$(sha256sum "$battery_limit_assets/$asset" | cut -d ' ' -f1)
    grep -Fxq "$digest  $receipt_asset" "$epoch_proof"
done
test "$(grep -Fxc 'Baseline reproduces publication from mixed settings epochs' "$epoch_proof")" = 2
test "$(grep -Fxc 'Candidate refuses crossed settings epochs and preserves stable reads and burst reuse' "$epoch_proof")" = 2
sha256sum -c --strict --quiet "$battery_limit_assets/epoch-pre.sha256"
git apply --check --whitespace=error "$epoch_patch"
git apply --whitespace=error "$epoch_patch"
sha256sum -c --strict --quiet "$battery_limit_assets/epoch-post.sha256"
# UKE_CHARGE_BAND_EPOCH_PREPARE_END
display_assets=$PWD/native-generated/normal-display-assets
printf '%%s  %%s\n' f93e2bef07dae46800cd2729ace96ebb9cacc8db34b171988b57d48fb0c544b1 %{SOURCE401} | sha256sum -c --strict --quiet -
mkdir "$display_assets"
tar -xJf %{SOURCE401} -C "$display_assets"
(cd "$display_assets"; sha256sum -c --strict --quiet SHA256SUMS)
bash "$display_assets/prepare-normal-display.sh" prepare "$PWD"
# UKE_CAMSS_BUILTIN_PREPARE_BEGIN
camss_assets=$PWD/native-generated/normal-camss-assets
printf '%%s  %%s\n' 24b62a0b168e7d8e18f13d26bed98af035bbb8998465c0c651c873475da0e603 %{SOURCE406} | sha256sum -c --strict --quiet -
mkdir "$camss_assets"
tar -xJf %{SOURCE406} -C "$camss_assets"
(cd "$camss_assets" && sha256sum -c --strict --quiet SHA256SUMS)
camss_fixture="$camss_assets/layout-qualification.txt"
rpm2cpio "$camss_assets/uke-kernel-migration-check-7.3.5-10.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-kernel-migration-check/camss-published-layout735/qualification.txt > "$camss_fixture"
test "$(grep -c '^Refused: ' "$camss_fixture")" = 11
grep -Fxq 'Verified: linked ARM64 DYN and matching packaged symbols, metadata and FDT.' "$camss_fixture"
camss_objects="$camss_assets/objects-qualification.txt"
rpm2cpio "$camss_assets/uke-kernel-migration-check-7.3.5-5.fc46.aarch64.rpm" |
    cpio -i --quiet --to-stdout ./usr/share/uke-kernel-migration-check/camss-receive735/qualification.txt > "$camss_objects"
grep -Fxq 'ARM64 built-in CAMSS archive and CAMCC provider; camera graph unchanged.' "$camss_objects"
grep '^[-a-f0-9]\{64\}  \(drivers/.*\.[ch]\|include/.*\.h\)$' "$camss_objects" | cmp - "$camss_assets/combined-source.sha256"
bash "$camss_assets/camss-late-layer735.sh" prepare "$PWD"
node "$camss_assets/camss-boot-view735.mjs" "$vi_boot" "$vi_checker"
bash -n "$vi_boot"
bash -n "$vi_checker"
# UKE_CAMSS_BUILTIN_PREPARE_END
root_probe_assets=$PWD/native-generated/normal-root-probe-assets
root_probe_rollback=$PWD/native-generated/normal-root-probe-rollback
observation_assets=$PWD/native-generated/normal-observation-assets
printf '%%s  %%s\n' ec8089f869207cffa482a66f94c936070cffce9a566f95a93da9fb61e2112f92 %{SOURCE407} 6a83498907f2c772b5222ba6edbacc611e766a1070b3d336a1a76183dcc849a0 %{SOURCE408} | sha256sum -c --strict --quiet -
mkdir "$root_probe_assets" "$observation_assets"
tar -xJf %{SOURCE407} -C "$root_probe_assets"
tar -xJf %{SOURCE408} -C "$observation_assets"
(cd "$root_probe_assets"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$observation_assets"; sha256sum -c --strict --quiet SHA256SUMS)
observation_proof="$observation_assets/uke-kernel-migration-check-7.3.5-15.fc46.aarch64.rpm"
printf '%%s  %%s\n' ba8fad91af70f39de1dc8a363836fed225de0346fd2bb52e95c085ade5eaaade "$observation_proof" | sha256sum -c --strict --quiet -
observation_receipt="$observation_assets/qualification.txt"
rpm2cpio "$observation_proof" |
    cpio -i --quiet --to-stdout './usr/share/uke-kernel-migration-check/normal-observations735/qualification.txt' > "$observation_receipt"
grep -Fxq 'Parent: signed normal 7.4.7 source, COPR 11365568' "$observation_receipt"
grep -Fxq 'Actual ARM64 battery and AudioReach objects contain the three observation changes.' "$observation_receipt"
grep -Fxq 'Combined observations reversed to the exact signed 7.4.7 preimages.' "$observation_receipt"
(
    cd "$observation_assets"
    find . -type f ! -name SHA256SUMS ! -name qualification.txt ! -name 'uke-kernel-migration-check-7.3.5-15.fc46.aarch64.rpm' -print0 |
        LC_ALL=C sort -z | xargs -0 sha256sum |
        while IFS= read -r source; do grep -Fxq "$source" "$observation_receipt" || exit 1; done
)
bash "$observation_assets/prepare-normal-observation-overlay.sh" prepare "$PWD"
transport_charge_assets=$PWD/native-generated/normal-transport-charge-assets
printf '%%s  %%s\n' 60094e1242e5295e529535522ce2bf022043a5ffe788cd987c70c6a797bded1c %{SOURCE412} | sha256sum -c --strict --quiet -
mkdir "$transport_charge_assets"
tar -xJf %{SOURCE412} -C "$transport_charge_assets"
bash "$transport_charge_assets/prepare-normal-transport-charge.sh" prepare "$PWD"
burst_assets=$PWD/native-generated/normal-battery-status-burst-assets
printf '%%s  %%s\n' 23686f0c6ddcc0d5780fef26ad04b10a35a9727c2e88bf8cfea784ea7240790f %{SOURCE416} | sha256sum -c --strict --quiet -
mkdir "$burst_assets"
tar -xJf %{SOURCE416} -C "$burst_assets"
bash "$burst_assets/prepare-battery-status-burst.sh" prepare "$PWD"
fcc_rproc_assets=$PWD/native-generated/normal-fcc-remoteproc-assets
printf '%%s  %%s\n' deaac33f3aea860085447177864d8c136b1abc314d099c0e97557bd47290f150 %{SOURCE417} | sha256sum -c --strict --quiet -
mkdir "$fcc_rproc_assets"
tar -xJf %{SOURCE417} -C "$fcc_rproc_assets"
bash "$fcc_rproc_assets/prepare-fcc-remoteproc.sh" prepare "$PWD"
epoch_assets="$PWD/native-generated/normal-fixed-cap-epoch-assets"
printf '%%s  %%s\n' de582397521396819fe57dc4356162fef988b870b17d48fdeb7cff98ccb8a9c0 %{SOURCE418} | sha256sum -c --strict --quiet -
mkdir "$epoch_assets"
tar -xJf %{SOURCE418} -C "$epoch_assets"
bash "$epoch_assets/overlay/prepare-fixed-cap-epoch735.sh" prepare "$PWD"
rgb_ssc_assets="$PWD/native-generated/normal-rgb-ssc-assets"
printf '%%s  %%s\n' ec84360ce6335b4e285ced16f92720fc30bbfe8118e816ca0decda8105872d6c %{SOURCE419} | sha256sum -c --strict --quiet -
mkdir "$rgb_ssc_assets"
tar -xJf %{SOURCE419} -C "$rgb_ssc_assets"
bash "$rgb_ssc_assets/overlay/prepare-rgb-ssc735.sh" prepare "$PWD"
touch_progress_assets="$PWD/native-generated/normal-touch-watchdog-assets"
printf '%%s  %%s\n' f05b7b80a073d5583972871af4e0631822f9b61147b5e9bfacc6d3bcc2f2b02c %{SOURCE420} | sha256sum -c --strict --quiet -
mkdir "$touch_progress_assets"
tar -xJf %{SOURCE420} -C "$touch_progress_assets"
bash "$touch_progress_assets/overlay/prepare-touch-watchdog735.sh" prepare "$PWD"
touch_distinct_assets="$PWD/native-generated/normal-touch-distinct-assets"
printf '%%s  %%s\n' a21fce194b00af6ae1bd760400e0fcf21f2d652a5fd0f6731234395468fa636f %{SOURCE422} | sha256sum -c --strict --quiet -
mkdir "$touch_distinct_assets"
tar -xJf %{SOURCE422} -C "$touch_distinct_assets"
bash "$touch_distinct_assets/overlay/prepare-touch-distinct735.sh" prepare "$PWD"
bash "$root_probe_assets/prepare-normal-root-probe.sh" prepare "$PWD/boot-recipe" %{uke_boot_userspace} "$root_probe_rollback"
feedback_geni_assets=$PWD/native-generated/normal-feedback-geni-assets
printf '%%s  %%s\n' e7842ecb237472c4df8a67db6111a95ff7cc3c9686ee62235210cc800f41aecf %{SOURCE413} | sha256sum -c --strict --quiet -
mkdir "$feedback_geni_assets"
tar -xJf %{SOURCE413} -C "$feedback_geni_assets"
bash "$feedback_geni_assets/prepare-feedback-geni.sh" prepare "$PWD"
gpi_assets=$PWD/native-generated/normal-gpi-assets
printf '%%s  %%s\n' 9a78ae2eb6a1b8d5ebf179cc53e7aa1d3cebd348c8b182699e7453aeea5c93f7 %{SOURCE415} | sha256sum -c --strict --quiet -
mkdir "$gpi_assets"
tar -xJf %{SOURCE415} -C "$gpi_assets"
bash "$gpi_assets/prepare-gpi.sh" prepare "$PWD"
ktz_assets=$PWD/native-generated/normal-ktz-minimum-assets
printf '%%s  %%s\n' a867c77b9e0541c26fb44b0fdc4d6bd10b2e8339b62f7075803752f3fbe60c04 %{SOURCE414} | sha256sum -c --strict --quiet -
mkdir "$ktz_assets"
tar -xJf %{SOURCE414} -C "$ktz_assets"
bash "$ktz_assets/prepare-ktz-minimum.sh" prepare "$PWD"
display_cap_assets=$PWD/native-generated/normal-display-cap-status-assets
printf '%%s  %%s\n' 5cd55eb5ce9db3f12dfcb7f1524b7d57bab9c750e87ecc3f0a3123322273180a %{SOURCE423} | sha256sum -c --strict --quiet -
mkdir "$display_cap_assets"
tar -xJf %{SOURCE423} -C "$display_cap_assets"
bash "$display_cap_assets/overlay/prepare-display-cap-status735.sh" prepare "$PWD"
pack_voltage_assets=$PWD/native-generated/normal-pack-voltage-assets
printf '%%s  %%s\n' c1448ccd3c790aab1f00ce1da34e1c3e882b3acb2488187897b161b3680807c4 %{SOURCE424} | sha256sum -c --strict --quiet -
mkdir "$pack_voltage_assets"
tar -xJf %{SOURCE424} -C "$pack_voltage_assets"
bash "$pack_voltage_assets/overlay/prepare-pack-voltage73526.sh" prepare "$PWD"
hbr3_assets=$PWD/native-generated/normal-hbr3-trial-assets
printf '%%s  %%s\n' c757a4e1aaa9531d5c07aa3ff53b47a4fc694fb28ff64398084727206881e26d %{SOURCE425} | sha256sum -c --strict --quiet -
mkdir "$hbr3_assets"
tar -xJf %{SOURCE425} -C "$hbr3_assets"
bash "$hbr3_assets/overlay/compile-hbr3-profile.sh" "$PWD"
bash "$hbr3_assets/overlay/prepare-hbr3-trial73526.sh" prepare "$PWD"
pmic_safe_assets=$PWD/native-generated/pmic_safe_assets
printf '%%s  %%s\n' df46ad746cb2b65715570760dea24c8ea455fa7739f4087ac50158ac92befd71 %{SOURCE426} | sha256sum -c --strict --quiet -
mkdir "$pmic_safe_assets"
tar -xJf %{SOURCE426} -C "$pmic_safe_assets"
bash "$pmic_safe_assets/overlay/prepare-safe-detach73527.sh" prepare "$PWD"
hbr3_recovery_assets=$PWD/native-generated/hbr3_recovery_assets
printf '%%s  %%s\n' 450881e6abcb7a6f63548c66f6b28e0f62b44dd1f43be84f053a969c5ab95c6b %{SOURCE427} | sha256sum -c --strict --quiet -
mkdir "$hbr3_recovery_assets"
tar -xJf %{SOURCE427} -C "$hbr3_recovery_assets"
bash "$hbr3_recovery_assets/overlay/prepare-hbr3-fallback.sh" prepare "$PWD"
dpu_optional_assets=$PWD/native-generated/dpu_optional_assets
printf '%%s  %%s\n' 472b2fb86b3c3d485f15daaead5af2f2b5b3142cc57122f476ede5720fc9ca76 %{SOURCE428} | sha256sum -c --strict --quiet -
mkdir "$dpu_optional_assets"
tar -xJf %{SOURCE428} -C "$dpu_optional_assets"
bash "$dpu_optional_assets/overlay/prepare-dpu-optional-dspp.sh" prepare "$PWD"
ov08d10_assets=$PWD/native-generated/ov08d10_reset
printf '%%s  %%s\n' 8726f3109396bd6cf9388c8c3c162066a928df5725cbb1a868ec0188e949109a %{SOURCE429} | sha256sum -c --strict --quiet -
mkdir "$ov08d10_assets"
tar -xJf %{SOURCE429} -C "$ov08d10_assets"
bash "$ov08d10_assets/overlay/prepare-ov08d10-reset73527.sh" prepare "$PWD"
front_vdig_assets=$PWD/native-generated/front_vdig_demand
printf '%%s  %%s\n' 862de62ac0dbdac25dde1a478e7765936873f0237e7565e2b5f4b158fec7a4c4 %{SOURCE430} | sha256sum -c --strict --quiet -
mkdir "$front_vdig_assets"
tar -xJf %{SOURCE430} -C "$front_vdig_assets"
bash "$front_vdig_assets/overlay/prepare-front-vdig-demand.sh" prepare "$PWD"
mst_controller_assets=$PWD/native-generated/mst_controller_pm
printf '%%s  %%s\n' 32f3662ba97bf4212d0428530c94bf6901f3dff43eefa1e28979f6ac424fd5db %{SOURCE431} | sha256sum -c --strict --quiet -
mkdir "$mst_controller_assets"
tar -xJf %{SOURCE431} -C "$mst_controller_assets"
bash "$mst_controller_assets/overlay/prepare-mst-detect-controller.sh" prepare "$PWD"
juo_display_assets=$PWD/native-generated/juo_display
printf '%%s  %%s\n' 0e7a12820cbb41882892253883823bd0ea3326b89bbf8d48023ec46e741850ee %{SOURCE432} | sha256sum -c --strict --quiet -
mkdir "$juo_display_assets"
tar -xJf %{SOURCE432} -C "$juo_display_assets"
bash "$juo_display_assets/overlay/prepare-juo-display73530.sh" prepare "$PWD"
usb_dp_assets=$PWD/native-generated/usb_dp_stability
printf '%%s  %%s\n' 3f2e2c53abdd1a12819cb2886950929067181bc2fa1ef87b1ee3f68f0c9f08c0 %{SOURCE433} | sha256sum -c --strict --quiet -
mkdir "$usb_dp_assets"
tar -xJf %{SOURCE433} -C "$usb_dp_assets"
bash "$usb_dp_assets/overlay/prepare-usb-dp-stability73531.sh" prepare "$PWD"
display_fault_assets=$PWD/native-generated/display_fault
printf '%%s  %%s\n' 11afe01064fa2a98662afce1e48fba71a7b2c369a7a9850601f359b2b24baf11 %{SOURCE434} | sha256sum -c --strict --quiet -
mkdir "$display_fault_assets"
tar -xJf %{SOURCE434} -C "$display_fault_assets"
bash "$display_fault_assets/overlay/prepare-display-fault73531.sh" prepare "$PWD"
dpu_atomic_assets=$PWD/native-generated/dpu_atomic_total
printf '%%s  %%s\n' 5a47f945c896985f4c422e58c19f7b73b731866f4b0b63cd72cdd2ffd265ee08 %{SOURCE435} | sha256sum -c --strict --quiet -
mkdir "$dpu_atomic_assets"
tar -xJf %{SOURCE435} -C "$dpu_atomic_assets"
bash "$dpu_atomic_assets/overlay/prepare-dpu-atomic-total.sh" prepare "$PWD"
mst_slot_assets=$PWD/native-generated/mst_single_payload
printf '%%s  %%s\n' ebeb950598e804683e84eccf68b759d8e1f5028a38b33c568c4bd735557c1cd9 %{SOURCE436} | sha256sum -c --strict --quiet -
mkdir "$mst_slot_assets"
tar -xJf %{SOURCE436} -C "$mst_slot_assets"
bash "$mst_slot_assets/overlay/prepare-mst-slot-budget.sh" prepare "$PWD"
dp_attach_assets=$PWD/native-generated/dp_attach_ownership
printf '%%s  %%s\n' 62d1671e4df4703d8f875941464d153ae1e3fca83175353d3545bc3cd4b861dc %{SOURCE437} | sha256sum -c --strict --quiet -
mkdir "$dp_attach_assets"
tar -xJf %{SOURCE437} -C "$dp_attach_assets"
bash "$dp_attach_assets/overlay/prepare-dp-attach-ownership.sh" prepare "$PWD"
mst_rate_assets=$PWD/native-generated/mst_rate_governor
printf '%%s  %%s\n' bfac8d338bd021bcaf4682958e73cc258622ddc19fe9dbc96ae4347aae8c527a %{SOURCE438} | sha256sum -c --strict --quiet -
mkdir "$mst_rate_assets"
tar -xJf %{SOURCE438} -C "$mst_rate_assets"
bash "$mst_rate_assets/overlay/prepare-mst-rate-governor.sh" prepare "$PWD"
mst_encoder_assets=$PWD/native-generated/mst_encoder_prepass
printf '%%s  %%s\n' a35babf246867daad963463c57783dce2fb1606acccf46f63864273cff5671dc %{SOURCE439} | sha256sum -c --strict --quiet -
mkdir "$mst_encoder_assets"
tar -xJf %{SOURCE439} -C "$mst_encoder_assets"
bash "$mst_encoder_assets/overlay/prepare-mst-encoder-prepass.sh" prepare "$PWD"
altmode_hpd_assets=$PWD/native-generated/altmode_hpd_assets
printf '%%s  %%s\n' 6170872eaed46b42582fef07c3c422386865e3af641e31feb4ae983c69cdb90c %{SOURCE440} | sha256sum -c --strict --quiet -
mkdir "$altmode_hpd_assets"
tar -xJf %{SOURCE440} -C "$altmode_hpd_assets"
bash "$altmode_hpd_assets/overlay/prepare-altmode-hpd-route-error.sh" prepare "$PWD"
battmgr_deadline_assets=$PWD/native-generated/battmgr_deadline_assets
printf '%%s  %%s\n' e1529cdc9bf1520e8ae34c81aea798b482eaae0d697e5e89db1c20dc2a7bd4a6 %{SOURCE441} | sha256sum -c --strict --quiet -
mkdir "$battmgr_deadline_assets"
tar -xJf %{SOURCE441} -C "$battmgr_deadline_assets"
bash "$battmgr_deadline_assets/overlay/prepare-battmgr-deadline.sh" prepare "$PWD"
bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base '%{krel}' "$jobs" fs19xx-vi-diagnostic
for object in drivers/dma/qcom/gpi.o drivers/gpu/drm/msm/disp/dpu1/{dpu_core_perf,dpu_plane}.o; do
    llvm-readelf -h "%{_uke_out}/$object" | grep -F AArch64
done
llvm-readelf -h "%{_uke_out}/drivers/gpu/drm/msm/msm_atomic.o" | grep -F AArch64
for object in dpu_crtc dpu_kms; do
    llvm-readelf -h "%{_uke_out}/drivers/gpu/drm/msm/disp/dpu1/$object.o" | grep -F AArch64
done
llvm-nm --defined-only "%{_uke_out}/drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o" |
    grep -E '[[:space:]]dpu_core_perf_atomic_check$'
for object in dp_ctrl dp_display dp_mst_drm; do
    llvm-readelf -h "%{_uke_out}/drivers/gpu/drm/msm/dp/$object.o" | grep -F AArch64
done
llvm-readelf -h "%{_uke_out}/drivers/soc/qcom/pmic_glink_altmode.o" | grep -F AArch64
bash "$altmode_hpd_assets/overlay/prepare-altmode-hpd-route-error.sh" restore "$PWD"
llvm-readelf -h "%{_uke_out}/drivers/power/supply/qcom_battmgr.o" | grep -F AArch64
bash "$battmgr_deadline_assets/overlay/prepare-battmgr-deadline.sh" restore "$PWD"
bash "$mst_encoder_assets/overlay/prepare-mst-encoder-prepass.sh" restore "$PWD"
bash "$mst_rate_assets/overlay/prepare-mst-rate-governor.sh" restore "$PWD"
bash "$dp_attach_assets/overlay/prepare-dp-attach-ownership.sh" restore "$PWD"
bash "$mst_slot_assets/overlay/prepare-mst-slot-budget.sh" restore "$PWD"
bash "$dpu_atomic_assets/overlay/prepare-dpu-atomic-total.sh" restore "$PWD"
bash "$display_fault_assets/overlay/prepare-display-fault73531.sh" restore "$PWD"
for object in dp_aux dp_ctrl dp_display dp_mst_drm; do
    llvm-readelf -h "%{_uke_out}/drivers/gpu/drm/msm/dp/$object.o" | grep -F AArch64
done
bash "$usb_dp_assets/overlay/prepare-usb-dp-stability73531.sh" restore "$PWD"
for object in drivers/gpu/drm/msm/dp/dp_display.o drivers/gpu/drm/msm/dp/dp_mst_drm.o drivers/gpu/drm/display/drm_dp_mst_topology.o; do
    llvm-readelf -h "%{_uke_out}/$object" | grep -F AArch64
done
bash "$juo_display_assets/overlay/prepare-juo-display73530.sh" restore "$PWD"
mst_controller_object="%{_uke_out}/drivers/gpu/drm/msm/dp/dp_mst_drm.o"
llvm-readelf -h "$mst_controller_object" | grep -F AArch64
llvm-nm "$mst_controller_object" > "$mst_controller_assets/linked-symbols.txt"
grep -E ' U drm_dp_mst_detect_port$' "$mst_controller_assets/linked-symbols.txt"
bash "$mst_controller_assets/overlay/prepare-mst-detect-controller.sh" restore "$PWD"
for object in drivers/regulator/qcom-rpmh-regulator-uke.o arch/arm64/kernel/uke-abl.o; do
    llvm-readelf -h "%{_uke_out}/$object" | grep -F AArch64
    strings "%{_uke_out}/$object" | grep -Fx 'xiaomi,uke-front-vdig-demand-only'
done
bash "$front_vdig_assets/overlay/prepare-front-vdig-demand.sh" restore "$PWD"
ov08d10_object="%{_uke_out}/drivers/media/i2c/ov08d10.o"
llvm-readelf -h "$ov08d10_object" | grep -F AArch64
strings "$ov08d10_object" | grep -F 'failed to release sensor reset'
bash "$ov08d10_assets/overlay/prepare-ov08d10-reset73527.sh" restore "$PWD"
for object in drivers/soc/qcom/pmic_glink_altmode.o drivers/phy/qualcomm/phy-qcom-qmp-combo.o drivers/gpu/drm/msm/dp/dp_ctrl.o drivers/gpu/drm/msm/disp/dpu1/dpu_rm.o; do
    llvm-readelf -h "%{_uke_out}/$object" | grep -F AArch64
done
altmode_symbols="$pmic_safe_assets/linked-symbols.txt"
llvm-nm "%{_uke_out}/drivers/soc/qcom/pmic_glink_altmode.o" > "$altmode_symbols"
grep -E ' U mod_delayed_work_on$' "$altmode_symbols"
grep -E ' U disable_delayed_work_sync$' "$altmode_symbols"
printf 'Uke Type-C detach, HBR3 startup recovery and optional DSPP diagnostics compiled.\n'
bash "$dpu_optional_assets/overlay/prepare-dpu-optional-dspp.sh" restore "$PWD"
bash "$hbr3_recovery_assets/overlay/prepare-hbr3-fallback.sh" restore "$PWD"
bash "$pmic_safe_assets/overlay/prepare-safe-detach73527.sh" restore "$PWD"
bash "$hbr3_assets/overlay/check-hbr3-linked.sh" %{_uke_out} "$PWD" '%{krel}'
bash "$hbr3_assets/overlay/prepare-hbr3-trial73526.sh" restore "$PWD"
bash "$pack_voltage_assets/overlay/prepare-pack-voltage73526.sh" linked %{_uke_out} '%{krel}'
bash "$pack_voltage_assets/overlay/prepare-pack-voltage73526.sh" restore "$PWD"
bash "$display_cap_assets/overlay/prepare-display-cap-status735.sh" linked %{_uke_out} '%{krel}'
bash "$display_cap_assets/overlay/prepare-display-cap-status735.sh" restore "$PWD"
bash "$ktz_assets/prepare-ktz-minimum.sh" linked %{_uke_out} '%{krel}'
bash "$ktz_assets/prepare-ktz-minimum.sh" restore "$PWD"
bash "$gpi_assets/prepare-gpi.sh" linked %{_uke_out} '%{krel}'
bash "$gpi_assets/prepare-gpi.sh" restore "$PWD"
bash "$feedback_geni_assets/prepare-feedback-geni.sh" linked %{_uke_out} '%{krel}'
bash "$feedback_geni_assets/prepare-feedback-geni.sh" restore "$PWD"
bash "$root_probe_assets/prepare-normal-root-probe.sh" embedded %{_uke_out}/boot-initramfs.cpio.gz
bash "$root_probe_assets/prepare-normal-root-probe.sh" restore "$PWD/boot-recipe" %{uke_boot_userspace} "$root_probe_rollback"
bash "$transport_charge_assets/prepare-normal-transport-charge.sh" linked %{_uke_out} '%{krel}'
bash "$burst_assets/prepare-battery-status-burst.sh" linked %{_uke_out} '%{krel}'
bash "$fcc_rproc_assets/prepare-fcc-remoteproc.sh" linked %{_uke_out} '%{krel}'
bash "$epoch_assets/overlay/prepare-fixed-cap-epoch735.sh" linked %{_uke_out} '%{krel}'
bash "$rgb_ssc_assets/overlay/prepare-rgb-ssc735.sh" linked %{_uke_out} '%{krel}'
bash "$touch_progress_assets/overlay/prepare-touch-watchdog735.sh" linked %{_uke_out} '%{krel}'
bash "$touch_distinct_assets/overlay/prepare-touch-distinct735.sh" restore "$PWD"
bash "$touch_progress_assets/overlay/prepare-touch-watchdog735.sh" restore "$PWD"
bash "$rgb_ssc_assets/overlay/prepare-rgb-ssc735.sh" restore "$PWD"
bash "$epoch_assets/overlay/prepare-fixed-cap-epoch735.sh" restore "$PWD"
bash "$fcc_rproc_assets/prepare-fcc-remoteproc.sh" restore "$PWD"
bash "$burst_assets/prepare-battery-status-burst.sh" restore "$PWD"
bash "$transport_charge_assets/prepare-normal-transport-charge.sh" restore "$PWD"
bash "$observation_assets/prepare-normal-observation-overlay.sh" linked %{_uke_out} '%{krel}'
bash "$observation_assets/prepare-normal-observation-overlay.sh" restore "$PWD"
bash "$camss_assets/check-camss-built-in735.sh" %{_uke_out} '%{krel}'
bash "$camss_assets/camss-late-layer735.sh" restore "$PWD"
mv -- "$vi_layer/migration-check-parent.sh" "$vi_checker"
bash "$display_assets/prepare-normal-display.sh" linked %{_uke_out} '%{krel}'
bash "$display_assets/prepare-normal-display.sh" restore "$PWD"
charge_module=%{_uke_out}/drivers/power/supply/qcom_battmgr.ko
test -s "$charge_module"
readelf -h "$charge_module" | grep -F AArch64
strings "$charge_module" > "$charge_layer/linked-exports.txt"
for field in uvdm_state_raw fg1_rsoc_raw batt_capacity_raw; do
    grep -Fx "uke_oem_$field" "$charge_layer/linked-exports.txt"
done
# UKE_CHARGE_BAND_EPOCH_RESTORE_BEGIN
sha256sum -c --strict --quiet "$battery_limit_assets/epoch-post.sha256"
git apply --reverse --check --whitespace=error "$epoch_patch"
git apply --reverse --whitespace=error "$epoch_patch"
sha256sum -c --strict --quiet "$battery_limit_assets/epoch-pre.sha256"
# UKE_CHARGE_BAND_EPOCH_RESTORE_END
# UKE_BATTERY_POWER_OBSERVATION_RESTORE_BEGIN
grep -Fx uke_oem_batt_power_now_raw "$charge_layer/linked-exports.txt"
sha256sum -c --strict --quiet "$battery_limit_assets/power-post.sha256"
git apply --reverse --check --whitespace=error "$battery_power_patch"
git apply --reverse --whitespace=error "$battery_power_patch"
sha256sum -c --strict --quiet "$battery_limit_assets/power-pre.sha256"
test ! -e Documentation/ABI/testing/sysfs-driver-qcom-battmgr-uke-power-raw
# UKE_BATTERY_POWER_OBSERVATION_RESTORE_END
# UKE_BATTERY_LIMIT_OBSERVATION_RESTORE_BEGIN
for field in batt_limit_raw batt_limit_max_raw; do
    grep -Fx "uke_oem_$field" "$charge_layer/linked-exports.txt"
done
sha256sum -c --strict --quiet "$battery_limit_assets/post.sha256"
git apply --reverse --check --whitespace=error "$battery_limit_patch"
git apply --reverse --whitespace=error "$battery_limit_patch"
sha256sum -c --strict --quiet "$battery_limit_assets/pre.sha256"
test ! -e Documentation/ABI/testing/sysfs-driver-qcom-battmgr-uke-limit-raw
# UKE_BATTERY_LIMIT_OBSERVATION_RESTORE_END
# UKE_THRESHOLD_OBSERVATION_RESTORE_BEGIN
sha256sum -c --strict --quiet "$threshold_assets/after.sha256"
git apply --reverse --check --whitespace=error "$threshold_patch"
git apply --reverse --whitespace=error "$threshold_patch"
sha256sum -c --strict --quiet "$threshold_assets/before.sha256"
# UKE_THRESHOLD_OBSERVATION_RESTORE_END
git apply --reverse --check --whitespace=error "$usb_type_patch"
git apply --reverse --whitespace=error "$usb_type_patch"
printf '%%s  %%s\n' 238500f7825481331b563bb95a836b639a80a4e286f663f1336d9598e9d42b51 "$usb_type_source" | sha256sum -c --strict --quiet -
bash "$charge_assets/normal-charge-layer.sh" restore "$PWD" "$charge_layer"
mv -- "$vi_layer/boot-payload-parent.sh" "$vi_boot"
grep -Fx 'CONFIG_SND_SOC_FS19XX_UKE_VI_DIAGNOSTIC=y' %{_uke_out}/.config
grep -Fx '# CONFIG_SND_SOC_FS19XX_UKE_QUALIFIED_GAIN is not set' %{_uke_out}/.config
vi_module=%{_uke_out}/sound/soc/qcom/qdsp6/snd-q6apm.ko
test -s "$vi_module"
readelf -h "$vi_module" | grep -F AArch64
readelf -Ws "$vi_module" > "$vi_layer/linked-symbols.txt"
grep -E '[[:space:]]q6apm_vi_snapshot_show$' "$vi_layer/linked-symbols.txt"
grep -E '[[:space:]]uke_vi_session_close$' "$vi_layer/linked-symbols.txt"
[[ $(modinfo -F vermagic "$vi_module") == '%{krel} '* ]]
bash "$bsg_assets/apply-bsg-monitor735.sh" verify-and-restore "$PWD" %{_uke_out}
bash "$vi_assets/vi-layer.sh" restore "$PWD" "$vi_layer"
# Check linked providers and keep the panel outside the initramfs battery dependency chain.
o82_panel=%{_uke_out}/drivers/gpu/drm/panel/panel-xiaomi-o82.ko
o82_battery=%{_uke_out}/drivers/power/supply/qcom_battmgr.ko
test -s "$o82_panel"
test -s "$o82_battery"
nm --defined-only %{_uke_out}/vmlinux > "$followup/charge-screen-vmlinux.txt"
for entry in register unregister publish; do
    grep -E "[[:space:]]uke_o82_charge_screen_$entry\$" "$followup/charge-screen-vmlinux.txt"
done
modinfo -F depends "$o82_battery" | tr ',' '\n' > "$followup/charge-screen-battery-depends.txt"
if grep -Eq '(^|[-_])panel[-_]xiaomi[-_]o82($|[-_])' "$followup/charge-screen-battery-depends.txt"; then
    exit 1
fi
readelf -Ws "$o82_battery" > "$followup/charge-screen-battery-symbols.txt"
readelf -Ws "$o82_panel" > "$followup/charge-screen-panel-symbols.txt"
for entry in register unregister; do
    grep -E "[[:space:]]UND[[:space:]]+uke_o82_charge_screen_$entry\$" "$followup/charge-screen-battery-symbols.txt"
done
grep -E '[[:space:]]UND[[:space:]]+uke_o82_charge_screen_publish$' "$followup/charge-screen-panel-symbols.txt"
sha256sum -c --strict --quiet "$followup/charge-screen-prepared.sha256"
git apply --reverse --check --whitespace=error %{SOURCE296}
git apply --reverse --whitespace=error %{SOURCE296}
sha256sum -c --strict --quiet "$followup/charge-screen-preimage.sha256"
# Confirm the candidate objects, conservative gain, and fitted charger observation.
for module in sound/soc/qcom/qdsp6/snd-q6apm sound/soc/codecs/fs19xx drivers/power/supply/qcom_battmgr; do
    test -s "%{_uke_out}/$module.o"
    readelf -h "%{_uke_out}/$module.o" | grep -F AArch64 >/dev/null
done
grep -Fxq '# CONFIG_SND_SOC_FS19XX_UKE_QUALIFIED_GAIN is not set' %{_uke_out}/.config
grep -Fxq 'CONFIG_BATTERY_QCOM_BATTMGR_UKE_OEM_STATUS=y' %{_uke_out}/.config
grep -Fxq 'CONFIG_BATTERY_QCOM_BATTMGR_UKE_READY_PUBLICATION=y' %{_uke_out}/.config
readelf -Ws %{_uke_out}/drivers/power/supply/qcom_battmgr.o > "$followup/linked-battmgr-symbols.txt"
grep -E '[[:space:]]qcom_battmgr_uke_publish_battery$' "$followup/linked-battmgr-symbols.txt"
strings %{_uke_out}/drivers/power/supply/qcom_battmgr.o | grep -Fx 'uke_oem_usb_typec_compliant_raw'
sha256sum -c --strict --quiet "$followup/linked-charge-config.sha256"
sha256sum -c --strict --quiet "$followup/linked-source.sha256"
cp -p "$battery_source" "$followup/battmgr-final.c"
strings %{_uke_out}/drivers/power/supply/qcom_battmgr.o > "$followup/charge-modes-linked.txt"
for field in adapter_id_raw adapter_svid_raw night_charging_raw sport_mode_raw smart_sic_mode_raw; do
    grep -Fx "uke_oem_$field" "$followup/charge-modes-linked.txt"
done
ucsi_observer=%{_uke_out}/drivers/usb/typec/ucsi/typec_ucsi.o
test -s "$ucsi_observer"
readelf -h "$ucsi_observer" | grep -F AArch64 >/dev/null
strings "$ucsi_observer" > "$followup/ucsi-observer-linked.txt"
grep -Fx 'uke_pd_source_details' "$followup/ucsi-observer-linked.txt"
grep -Fx 'uke_pd_contract' "$followup/ucsi-observer-linked.txt"
# Keep the historical cache sources available to the older link fixtures.
printf '%%s  %%s\n' b9f5cb832ab77f95a5702de3424d5b575aa3e3103283a63143d8d7e1ab4a41f3 "$ucsi_now_file" | sha256sum -c --strict --quiet -
git apply --reverse --check --whitespace=error "$ucsi_now_patch"
git apply --reverse --whitespace=error "$ucsi_now_patch"
sha256sum -c --strict --quiet "$followup/linked-ucsi-observer.sha256"
for field in fast_charge_mode_raw apdo_max_raw; do
    grep -Fx "uke_oem_$field" "$followup/charge-modes-linked.txt"
done
readelf -Ws %{_uke_out}/sound/soc/codecs/fs19xx.o > "$followup/alsa-state-linked.txt"
grep -E '[[:space:]]UND[[:space:]]+capable_noaudit$' "$followup/alsa-state-linked.txt"
git apply --reverse --check --whitespace=error %{SOURCE294}
git apply --reverse --whitespace=error %{SOURCE294}
printf '%s  %s\n' 3495370e97bf4ceef5e3907b264c182e8dcbda38ca724ff758311672c9e61ca2 "$feedback_codec" |
  sha256sum -c --strict --quiet -
# Historical link/layout fixtures inspect their signed source preimages.
for file in %{SOURCE292} %{SOURCE290}; do
    git apply --reverse --check --whitespace=error "$file"
    git apply --reverse --whitespace=error "$file"
done
git apply --reverse --check --whitespace=error %{SOURCE287}
git apply --reverse --whitespace=error %{SOURCE287}
git apply --reverse --check --whitespace=error %{SOURCE286}
git apply --reverse --whitespace=error %{SOURCE286}
git apply --reverse --check --whitespace=error %{SOURCE284}
git apply --reverse --whitespace=error %{SOURCE284}
git apply --reverse --check --whitespace=error %{SOURCE282}
git apply --reverse --whitespace=error %{SOURCE282}
git apply --reverse --check --whitespace=error %{SOURCE281}
git apply --reverse --whitespace=error %{SOURCE281}
for file in %{SOURCE279} %{SOURCE277} %{SOURCE275}; do
    git apply --reverse --check --whitespace=error "$file"
done
# Retain the qualified board defaults when the later config tests resolve their references.
git apply --check --whitespace=error %{SOURCE281}
git apply --whitespace=error %{SOURCE281}
git apply --include='*/Kconfig' --check --whitespace=error %{SOURCE284}
git apply --include='*/Kconfig' --whitespace=error %{SOURCE284}
git apply --check --whitespace=error %{SOURCE286}
git apply --whitespace=error %{SOURCE286}
sha256sum -c --strict --quiet "$followup/linked-charge-config.sha256"
cp -p "$apm_source" "$followup/q6apm-final.c"
cp -p "$feedback_codec" "$followup/fs19xx-final.c"
cp -p "$followup/q6apm-parent.c" "$apm_source"
cp -p "$followup/fs19xx-parent.c" "$feedback_codec"
cp -p "$followup/battmgr-parent.c" "$battery_source"
test -s %{_uke_out}/drivers/power/supply/qcom_battmgr.o
git apply --reverse --check --whitespace=error %{SOURCE273}
cp -p "$battery_source" "$battery_stage/candidate.c"
cp -p "$battery_stage/parent.c" "$battery_source"
# Modules have been linked, signed and staged. Retain their exact source
# separately while the historical package checks see the verified parent.
git apply --reverse --check --whitespace=error %{SOURCE270}
cp -p "$feedback_codec" "$feedback_stage/candidate.c"
cp -p "$feedback_stage/parent.c" "$feedback_codec"
printf '%s  %s\n' b85984dd3b06d4ae83dd3499b8372b7924209462c37a9017e868d441917b2927 "$feedback_codec" |
  sha256sum -c --strict --quiet -
# UKE_EARLY_PLYMOUTH734_LINKED_BEGIN
test -s %{_uke_out}/boot-initramfs/usr/lib64/plymouth/uke-physical.so
grep -Fxq 'Theme=senemos-uke' %{_uke_out}/boot-initramfs/etc/plymouth/plymouthd.conf
grep -Fxq 'CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER=y' %{_uke_out}/.config
grep -Fxq '# CONFIG_LOGO is not set' %{_uke_out}/.config
grep -Fq 'quiet loglevel=1 rd.systemd.show_status=no systemd.show_status=no splash' %{_uke_out}/.config
# UKE_EARLY_PLYMOUTH734_LINKED_END
# UKE_SUPER_FULL7344_PROFILES_BEGIN
test "$(grep -c '^PASS: super root' super-root734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet super-root734-result/source.sha256
bash full4/root15/tests/check-super-root-note734.sh %{_uke_out}/arch/arm64/boot/Image
test "$(stat -c%s %{_uke_out}/arch/arm64/boot/Image)" -le 96464896
for root_profile in userdata-super rescue;do
 %{_uke_out}/boot-image create-bootloader-compat %{_uke_out}/arch/arm64/boot/Image "%{_uke_out}/$root_profile.img" "$root_profile"
 %{_uke_out}/boot-image inspect "%{_uke_out}/$root_profile.img" | jq -e '.image_bytes==100663296 and .os_version_encoded==570425768 and .ramdisk_bytes==0 and .signature_bytes==0 and (.avb_footer_present|not)'
 %{_uke_out}/boot-image extract "%{_uke_out}/$root_profile.img" "%{_uke_out}/$root_profile-readback"
 cmp %{_uke_out}/arch/arm64/boot/Image "%{_uke_out}/$root_profile-readback"
 unlink "%{_uke_out}/$root_profile-readback"
done
jq -n --arg release '%{krel}' --arg raw "$(sha256sum %{_uke_out}/arch/arm64/boot/Image | cut -d' ' -f1)" \
 --arg userdata "$(sha256sum %{_uke_out}/userdata-super.img | cut -d' ' -f1)" \
 --arg rescue "$(sha256sum %{_uke_out}/rescue.img | cut -d' ' -f1)" \
 '{schema_version:1,kernel_release:$release,raw_image_sha256:$raw,capacity_bytes:100663296,
   seed_contract_bytes:4294967296,userdata_super_sha256:$userdata,rescue_sha256:$rescue,
   original_default_userdata_profile:true,kernel_capability_verified:true,physical_boot_tested:false}' > %{_uke_out}/super-profiles.json
unlink %{_uke_out}/userdata-super.img
unlink %{_uke_out}/rescue.img
# UKE_SUPER_FULL7344_PROFILES_END
bash native-hardware/packaging/native/prepare-native-hardware-full733.sh.publication "$uke_hwkm_parent" %{_uke_out} linked
bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh.publication "$PWD" %{_uke_out} linked
# UKE_CAMERA_FULL7346_HWKM_BEGIN
bash hwkm-early/packaging/native/prepare-hwkm-early733.sh.publication "$camera_full5_parent" %{_uke_out} linked
# UKE_CAMERA_FULL7346_HWKM_END
bash qtee-information/packaging/native/prepare-qtee-information733.sh.publication "$PWD" %{_uke_out} linked
mkdir "$vi_layer/legacy-config"
vi_config=$vi_layer/legacy-config/.config
camss_legacy_config="$vi_layer/camss-legacy.config"
bash "$camss_assets/camss-config735.sh" project %{_uke_out}/.config > "$camss_legacy_config"
sed 's/^CONFIG_SND_SOC_FS19XX_UKE_VI_DIAGNOSTIC=y$/# CONFIG_SND_SOC_FS19XX_UKE_VI_DIAGNOSTIC is not set/' "$camss_legacy_config" > "$vi_config"
diff -u "$vi_config" "$camss_legacy_config" > "$vi_layer/config-delta.patch" || test "$?" = 1
test "$(grep -Ec '^[+-](# )?CONFIG_' "$vi_layer/config-delta.patch")" = 2
node "$vi_assets/vi-boot-edit.mjs" - native-profile/packaging/native/prepare-storage-config-full733.sh.publication "$vi_layer/storage-linked-config.sh" storage
bash -n "$vi_layer/storage-linked-config.sh"
UKE_VI_LEGACY_CONFIG="$vi_config" bash "$vi_layer/storage-linked-config.sh" "$PWD" %{_uke_out} linked
for requirement in CONFIG_QCOM_UKE_ABL_DT=y CONFIG_PSI=y CONFIG_DRM_MSM=m \
    CONFIG_DRM_PANEL_XIAOMI_O82=m CONFIG_SM_DISPCC_8550=m \
    CONFIG_VIDEO_QCOM_IRIS=m CONFIG_SM_VIDEOCC_8550=m \
    CONFIG_DRM_FBDEV_EMULATION=y CONFIG_BACKLIGHT_KTZ8866=m \
    CONFIG_EXT4_FS=y CONFIG_F2FS_FS=y CONFIG_XFS_FS=y CONFIG_BTRFS_FS=y \
    CONFIG_QCOM_UKE_PLATFORM_PROFILE=y CONFIG_ACPI_PLATFORM_PROFILE=y \
    CONFIG_SND_SEQUENCER=m CONFIG_SND_SOC_UKE=m CONFIG_SND_SOC_FS19XX=m \
    CONFIG_PINCTRL_SM8650_LPASS_LPI=m CONFIG_PINCTRL_PALAWAN_LPASS_LPI=m CONFIG_FM19511_UKE=m \
    CONFIG_RC_CORE=m CONFIG_LIRC=y CONFIG_IR_SPI=m CONFIG_HW_RANDOM_QCOM=m \
    CONFIG_BLK_INLINE_ENCRYPTION=y CONFIG_SCSI_UFS_CRYPTO=y \
    CONFIG_QCOM_INLINE_CRYPTO_ENGINE=m; do
    grep -Fx "$requirement" %{_uke_out}/.config
done
grep -Fx '# CONFIG_PSI_DEFAULT_DISABLED is not set' %{_uke_out}/.config
test "$(make -s O=%{_uke_out} LOCALVERSION=-%{normal_rpm_release} kernelrelease)" = '%{krel}'

printf 'UKE_BUILD_STAGE boot_bundle elapsed_s=%d\n' "$((SECONDS-uke_build_start))"

# UKE_CAMERA_FULL7347_LINKED_BEGIN
sha256sum -c --strict --quiet camera-rom-report734-result/source.sha256
grep -aqF 'Uke camera ROM refusal:' %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o
grep -aqF 'Uke camera ROM refusal:' %{_uke_out}/arch/arm64/boot/Image
(cd %{_uke_out};sha256sum drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux) > camera-rom-report734-result/full-linked.sha256
# UKE_CAMERA_FULL7347_LINKED_END
# UKE_CAMERA_FULL7348_LINKED_BEGIN
sha256sum -c --strict --quiet camera-native7348-result/source.sha256
grep -aqF 'crm-native-plls' %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o
grep -aqF 'crm-native-plls' %{_uke_out}/arch/arm64/boot/Image
(cd %{_uke_out};sha256sum drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux) > camera-native7348-result/full-linked.sha256
# UKE_CAMERA_FULL7348_LINKED_END
# UKE_CAMERA_FULL7349_LINKED_BEGIN
sha256sum -c --strict --quiet camera-full7349-result/source.sha256
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/boot/Image
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/kernel/uke-abl.o
llvm-nm %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o | awk '$NF=="qcom_sm7675_camcc_status"{found=1}END{exit !found}'
(cd %{_uke_out};sha256sum arch/arm64/kernel/uke-abl.o drivers/clk/qcom/camcc-sm7675.o drivers/media/platform/qcom/camss/{camss,camss-csiphy,camss-vfe-gen3,camss-csid,camss-csid-gen3}.o arch/arm64/boot/Image vmlinux) > camera-full7349-result/full-linked.sha256
# UKE_CAMERA_FULL7349_LINKED_END
# UKE_CAMERA_FULL73410_LINKED_BEGIN
sha256sum -c --strict --quiet camera-full73410-result/source.sha256
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/boot/Image
cp camera-full7349-result/full-linked.sha256 camera-full73410-result/full-linked.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full73410-result/full-linked.sha256")
# UKE_CAMERA_FULL73410_LINKED_END
# UKE_CAMERA_ICC_HF_FULL734_LINKED_BEGIN
sha256sum -c --strict --quiet camera-icc-hf734-result/source.sha256
for name in icc-rpmh qnoc-cliffs-usb; do
    object="%{_uke_out}/drivers/interconnect/qcom/$name.o"
    llvm-readelf -h "$object" | grep -F AArch64
    grep -Fx "kernel/drivers/interconnect/qcom/$name.ko" %{_uke_out}/modules.builtin
done
grep -aqF qnm_camnoc_hf %{_uke_out}/arch/arm64/boot/Image
(cd %{_uke_out}; sha256sum drivers/interconnect/qcom/{icc-rpmh,qnoc-cliffs-usb}.o arch/arm64/boot/Image vmlinux) > camera-icc-hf734-result/full-linked.sha256
# UKE_CAMERA_ICC_HF_FULL734_LINKED_END
# UKE_GUNYAH_WATCHDOG_FULL734_LINKED_BEGIN
llvm-readelf -h %{_uke_out}/drivers/watchdog/gunyah_wdt.o | grep -F AArch64
grep -Fx 'kernel/drivers/watchdog/gunyah_wdt.ko' %{_uke_out}/modules.builtin
(cd %{_uke_out}; sha256sum drivers/watchdog/gunyah_wdt.o arch/arm64/boot/Image vmlinux) > native-generated/gunyah-watchdog734/full-linked.sha256
# UKE_GUNYAH_WATCHDOG_FULL734_LINKED_END
%check
export SENEMOS_PUBLICATION_ABI='%{krel}'
# RPM executes this phase in a fresh shell after the build and install.
vi_layer=$PWD/native-generated/normal-vi-linked
vi_config=$vi_layer/legacy-config/.config
test -s "$vi_config"
feedback_stage=$PWD/native-generated/fs19xx-feedback735
feedback_codec=$feedback_stage/candidate.c
feedback_module=%{_uke_out}/sound/soc/codecs/snd-soc-fs19xx.ko
printf '%s  %s\n' \
    b85984dd3b06d4ae83dd3499b8372b7924209462c37a9017e868d441917b2927 "$feedback_stage/parent.c" \
    6a3a88d307a91f89ad90c0a0e61c45bd3f2392f854bfc9ac38d045a576334bf1 "$feedback_codec" |
    sha256sum -c --strict --quiet -
for compiler in gcc clang; do
    CC="$compiler" bash %{SOURCE271} "$feedback_codec"
    CC="$compiler" SANITIZE=1 bash %{SOURCE271} "$feedback_codec"
done
llvm-readelf -h "$feedback_module" | grep -F AArch64
[[ $(modinfo -F vermagic "$feedback_module") == '%{krel} '* ]]
strings "$feedback_module" > "$feedback_stage/module-strings.txt"
grep -Fx 'Feedback Converter Status' "$feedback_stage/module-strings.txt"

(
set -o pipefail
check=native-generated/audio-power7352
git apply --reverse --check --whitespace=error %{SOURCE247}
bash native-generated/touch-ucsi735/overlay/check-layer.sh "$PWD" check native-generated/ucsi7353/prepared.sha256
for compiler in gcc clang; do
    CC="$compiler" bash native-generated/touch-ucsi735/overlay/ucsi-partner-pd-registration.sh "$PWD"
done
git apply --reverse --check --whitespace=error %{SOURCE254}
for compiler in gcc clang; do
    CC="$compiler" bash %{SOURCE248} "$PWD"
    CC="$compiler" bash %{SOURCE255} "$PWD" recheck
    CC="$compiler" bash %{SOURCE256} "$PWD"
done
for object in sound/soc/qcom/qdsp6/audioreach drivers/usb/typec/ucsi/{ucsi,psy,ucsi_glink}; do
    llvm-readelf -h "%{_uke_out}/$object.o" | grep -F AArch64
done
)
# UKE_SPEAKER_RGB_FULL734_CHECK_BEGIN
speaker_rgb_layer=$PWD/native-generated/speaker-rgb-input734/uke-speaker-rgb-source
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash "$speaker_rgb_layer/apply-speaker-rgb-full734.sh" "$PWD" "$speaker_rgb_layer" verify
# UKE_FS19XX_TELEMETRY734_CHECK_BEGIN
scenario_patch=$PWD/native-generated/scenario-layer/device-scenario.patch
(cd native-generated/scenario-layer; sha256sum -c --strict --quiet SHA256SUMS)
bash native-generated/scenario-layer/apply.sh "$PWD" verify
bash %{SOURCE261} "$PWD/native-generated/fs19xx-scenario735/parent" verify %{SOURCE259} %{SOURCE260}
git apply --reverse --check --whitespace=error %{SOURCE263}
iris_module=%{_uke_out}/drivers/media/platform/qcom/iris/qcom-iris.ko
llvm-readelf -h "$iris_module" | grep -F AArch64
[[ $(modinfo -F vermagic "$iris_module") == '%{krel} '* ]]
bash %{SOURCE269} "$PWD" verify %{SOURCE240} %{SOURCE241} %{SOURCE242} %{SOURCE259} "$scenario_patch"
(
module="%{_uke_out}/sound/soc/qcom/qdsp6/snd-q6apm.ko"
[[ $(modinfo -F vermagic "$module") == '%{krel} '* ]]
llvm-readelf -h "$module" | grep -F AArch64
llvm-nm -g --defined-only "$module" > native-generated/fs19xx-telemetry734/apm-symbols.txt
for entry in enables prediction coil; do
    grep -E "[[:space:]]T[[:space:]]q6apm_fs19xx_read_$entry$" native-generated/fs19xx-telemetry734/apm-symbols.txt
done
strings "$module" > native-generated/fs19xx-telemetry734/apm-strings.txt
grep -Fx 'FS19xx DSP Prediction x10' native-generated/fs19xx-telemetry734/apm-strings.txt
grep -Fx 'FS19xx DSP Coil Temperature Q12' native-generated/fs19xx-telemetry734/apm-strings.txt
)
fs19xx_parent=$(bash %{SOURCE269} "$PWD" project %{SOURCE240} %{SOURCE241} %{SOURCE242} %{SOURCE259} "$scenario_patch")
# UKE_FS19XX_TELEMETRY734_CHECK_END
for module in sound/soc/codecs/snd-soc-fs19xx drivers/leds/leds-uke-rgb; do
    [[ $(modinfo -F vermagic "%{_uke_out}/$module.ko") == '%{krel} '* ]]
done
# UKE_SPEAKER_RGB_FULL734_CHECK_END
# UKE_CAMERA_FULL73410_CHECK_BEGIN
sha256sum -c --strict --quiet camera-full73410-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full73410-result/full-linked.sha256")
jq -e '.compiler_modes==4 and .actual_arm64_objects==1 and .readonly_helper_unchanged and .real_interconnect_tag_converter and (.physical_camera_accepted|not)' front-stage734-result/qualification.json
jq -e '.compiler_modes==4 and .board_predicate_projection and .phandles_remapped and (.contains_unit_data|not) and (.contains_eeprom_contents|not) and (.physical_camera_accepted|not)' front-observed734-result/qualification.json
# UKE_CAMERA_FULL73410_CHECK_END
# UKE_CAMERA_ICC_HF_FULL734_CHECK_BEGIN
sha256sum -c --strict --quiet camera-icc-hf734-result/source.sha256
(cd %{_uke_out}; sha256sum -c --strict --quiet "$OLDPWD/camera-icc-hf734-result/full-linked.sha256")
# UKE_CAMERA_ICC_HF_FULL734_CHECK_END
# UKE_GUNYAH_WATCHDOG_FULL734_CHECK_BEGIN
sha256sum -c --strict --quiet native-generated/gunyah-watchdog734/gunyah-watchdog-source/layer/post.sha256
(cd %{_uke_out}; sha256sum -c --strict --quiet "$OLDPWD/native-generated/gunyah-watchdog734/full-linked.sha256")
# UKE_GUNYAH_WATCHDOG_FULL734_CHECK_END
# UKE_CAMERA_FULL7349_CHECK_BEGIN
sha256sum -c --strict --quiet camera-full7349-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full7349-result/full-linked.sha256")
jq -e '.compiler_modes==4 and .readonly_eeprom_only and .controller_then_quarantine_then_front and (.physical_camera_accepted|not)' front-eeprom734-result/qualification.json
# UKE_CAMERA_FULL7349_CHECK_END
# UKE_CAMERA_FULL7348_CHECK_BEGIN
sha256sum -c --strict --quiet camera-native7348-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-native7348-result/full-linked.sha256")
# UKE_CAMERA_FULL7348_CHECK_END
# UKE_CAMERA_FULL7347_CHECK_BEGIN
sha256sum -c --strict --quiet camera-rom-report734-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-rom-report734-result/full-linked.sha256")
# UKE_CAMERA_FULL7347_CHECK_END
# UKE_CAMERA_FULL7346_CHECK_BEGIN
camera_full5_parent=$(bash camera-full7346/camera-full5-legacy-view734.sh "$PWD")
sha256sum -c --strict --quiet camera-owner734-result/source.sha256 camera-owner734-result/retained.sha256
for family in owner rom startup floor composition caller;do
 test "$(wc -l < camera-owner734-result/$family-results.txt)" -ge 4
done
for marker in firmware-managed crm-rom crm-topology crm-startup crm-transport crm-attach;do
 grep -aqF "$marker" %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o
 grep -aqF "$marker" %{_uke_out}/arch/arm64/boot/Image
done
llvm-readelf -h %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o | grep -F AArch64
grep -Fx kernel/drivers/clk/qcom/camcc-sm7675.ko %{_uke_out}/modules.builtin
(cd %{_uke_out};sha256sum drivers/clk/qcom/camcc-sm7675.o arch/arm64/boot/Image vmlinux) > camera-owner734-result/full-linked.sha256
# UKE_CAMERA_FULL7346_CHECK_END
# UKE_DISPLAY_FULL7345_CHECK_BEGIN
test "$(grep -c '^PASS: display handoff' display-handoff734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet display-handoff734-result/source.sha256
# UKE_DISPLAY_FULL7345_CHECK_END
# UKE_SUPER_FULL7344_CHECK_BEGIN
test "$(grep -c '^PASS: super root' super-root734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet super-root734-result/source.sha256
bash full4/root15/tests/check-super-root-note734.sh %{_uke_out}/arch/arm64/boot/Image
test "$(jq -er .raw_image_sha256 %{_uke_out}/super-profiles.json)" = "$(sha256sum %{_uke_out}/arch/arm64/boot/Image | cut -d' ' -f1)"
test "$(jq -er .kernel_release %{_uke_out}/super-profiles.json)" = '%{krel}'
# UKE_SUPER_FULL7344_CHECK_END
# UKE_ABM_FULL7343_CHECK_BEGIN
test "$(grep -c '^PASS: native ABM' native-generated/abm734-native-results.txt)" = 4
sha256sum -c --strict --quiet abm734/src/display/abm734-post.sha256
llvm-nm %{_uke_out}/drivers/gpu/drm/msm/dsi/dsi_manager.o | awk '$NF=="qcom_uke_dsi_abm_register"{found=1}END{exit !found}'
llvm-nm %{_uke_out}/drivers/gpu/drm/panel/panel-xiaomi-o82.o | awk '$NF=="o82_abm_update"{found=1}END{exit !found}'
# UKE_ABM_FULL7343_CHECK_END
# UKE_STABLE734_FULL_CHECK_BEGIN
grep -Fxq 'CONFIG_LIVEPATCH=y' %{_uke_out}/.config
bash native-profile/tests/kernel-hardening-config-contract.sh %{_uke_out}/.config
openssl x509 -in native-profile/src/livepatch/uke-livepatch-20261115.pem -outform DER | cmp - %{_uke_out}/certs/x509_certificate_list
llvm-nm %{_uke_out}/vmlinux | awk '$NF=="klp_enable_patch"{found=1}END{exit !found}'
printf '%s  %s\n' "$(jq -er .after_encoder_sha256 native-profile/manifests/native-vrr734-20261115.json)" drivers/gpu/drm/msm/disp/dpu1/dpu_encoder.c | sha256sum -c --strict --quiet -
bash native-profile/tests/audio-identity734.sh "$PWD/native-profile" %{_uke_out}/sound/soc/qcom/uke-audio-card.ko
# UKE_STABLE734_FULL_CHECK_END
# UKE_CAMERA_FULL7346_VIEW_BEGIN
uke_hwkm_parent=$(bash camera-full7346/camera-hwkm-legacy-view7346.sh "$camera_full5_parent")
# UKE_CAMERA_FULL7346_VIEW_END
bash native-hardware/packaging/native/prepare-native-hardware-full733.sh.publication "$uke_hwkm_parent" %{_uke_out} check '%{buildroot}'
bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh.publication "$PWD" %{_uke_out} check '%{buildroot}'
# UKE_CAMERA_FULL7346_HWKM_BEGIN
bash hwkm-early/packaging/native/prepare-hwkm-early733.sh.publication "$camera_full5_parent" %{_uke_out} check '%{buildroot}'
# UKE_CAMERA_FULL7346_HWKM_END
bash qtee-information/packaging/native/prepare-qtee-information733.sh.publication "$PWD" %{_uke_out} check '%{buildroot}'
uke_native_parent=$(bash native-hardware/packaging/native/native-hardware-legacy-view733.sh "$uke_hwkm_parent")
bash native-profile/packaging/native/prepare-storage-config-full733.sh.publication "$PWD" %{_uke_out} check '%{buildroot}'
proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$uke_native_parent")
heading_parent=$(bash native-profile/packaging/native/heading-legacy-view733.sh "$proximity_parent")
buffer_parent=$(bash native-profile/packaging/native/quaternion-buffer-legacy-view733.sh "$heading_parent")
quaternion_parent=$(bash native-profile/packaging/native/quaternion-legacy-view733.sh "$buffer_parent")
gravity_parent=$(bash native-profile/packaging/native/gravity-legacy-view733.sh "$quaternion_parent")
# UKE_FS19XX_TELEMETRY734_PROJECTION_BEGIN
fs19xx_gravity_parent=$(bash %{SOURCE269} "$gravity_parent" project %{SOURCE240} %{SOURCE241} %{SOURCE242} %{SOURCE259} "$scenario_patch")
# UKE_FS19XX_TELEMETRY734_PROJECTION_END
bash native-profile/packaging/native/check-dual-light-delivery733.sh.publication "$gravity_parent" %{_uke_out} linked
bash native-profile/packaging/native/check-dual-light-binding733.sh "$gravity_parent" objects
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-stable733.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-stable733.sh.publication "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-stop-deadline733.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-stop-deadline733.sh.publication "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
bash native-profile/packaging/native/check-pcm-period733.sh.publication "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-enable-readback733.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-enable-readback733.sh.publication "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
bash native-profile/packaging/native/check-memory-compression733.sh.publication "$gravity_parent" %{_uke_out} linked
bash native-profile/packaging/native/check-hall-initial733.sh.publication "$gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-protected-stop731.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-protected-stop731.sh "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-client-byte-ready731.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-client-byte-ready731.sh "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-client-data731.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-client-data731.sh "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
bash native-profile/packaging/native/check-config-smmu731.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-oob-objects731.sh "$PWD" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-oob-objects731.sh "$fs19xx_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
bash native-profile/tests/migration-boot-config-boundary731.sh.publication "$PWD" "$PWD/native-generated/normal-vi-linked/legacy-config"
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-migration-cohort731.sh "$gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
cohort=native-profile/packaging/native/check-migration-cohort731.sh.publication
awk '/^( "\$before\/[.]config" |bash .*nfc-cohort-config731[.]sh" )"\$out\/[.]config" / {
    sub(/"\$out\/[.]config"/, "\"$UKE_VI_LEGACY_CONFIG\"")
    matches++
} {print} END {exit matches!=2}' "$cohort" > "$vi_layer/migration-linked-config.sh"
bash -n "$vi_layer/migration-linked-config.sh"
UKE_VI_LEGACY_CONFIG="$vi_config" bash "$vi_layer/migration-linked-config.sh" "$fs19xx_gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
bash native-generated/normal-vi-assets/vi-package-check.sh %{_uke_out}/.config native-generated/fs19xx-scenario735/candidate.tplg %{buildroot} '%{krel}' '%{version}-%{senemos_build_release}u'
protected_package=native-profile/tests/audio-protected-package-contract.sh.publication
protected_vi_package=$(mktemp native-profile/tests/audio-protected-package-vi.XXXXXXXX)
[[ $(grep -Fxc 'test -s "$first";cmp "$first" "$second"' "$protected_package") == 1 ]]
sed 's|^test -s "\$first";cmp "\$first" "\$second"$|test -s "$first";cmp "$firmware/sm7675/POCO-Pad-X1-VI-tplg.bin" "$second"|' "$protected_package" > "$protected_vi_package"
bash -n "$protected_vi_package"
bash "$protected_vi_package" "%{buildroot}" "%{_uke_out}" "$PWD/native-generated" "%{krel}"
rm -- "$protected_vi_package"
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" linked %{_uke_out}
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-speaker-inclusion.sh.publication "$fs19xx_parent" linked %{_uke_out}
# UKE_FS19XX_TELEMETRY734_RETAINED_END
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-cumulative-camera731.sh "$gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-cumulative-camera731.sh.publication "$fs19xx_gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
# UKE_FS19XX_TELEMETRY734_PRIOR_CHECK:bash native-profile/packaging/native/check-camera-next731.sh "$gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_BEGIN
bash native-profile/packaging/native/check-camera-next731.sh "$fs19xx_gravity_parent" %{_uke_out} linked
# UKE_FS19XX_TELEMETRY734_RETAINED_END
cmp native-profile/src/camera/camcc-sm7675.c "$uke_native_parent/drivers/clk/qcom/camcc-sm7675.c"
cmp native-profile/src/camera/provider/sysfs-driver-camcc-sm7675 Documentation/ABI/testing/sysfs-driver-camcc-sm7675
dual_light_legacy=$(bash native-profile/packaging/native/dual-light-legacy-view733.sh "$gravity_parent")
cmp native-profile/src/sensors/uke-ssc-iio.c "$dual_light_legacy/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
cmp native-profile/src/sensors/sysfs-driver-uke-ssc "$gravity_parent/Documentation/ABI/testing/sysfs-driver-uke-ssc"
llvm-nm %{_uke_out}/drivers/iio/common/uke-ssc/uke-ssc-iio.o > native-generated/ssc-observation-symbols.txt
for field in service_count lookup_fault suspended client_connected declared_sensors discovered_sensors ready_sensors registered_sensors last_error last_error_stage; do
 grep -Eq "[[:space:]]ssc_${field}_show$" native-generated/ssc-observation-symbols.txt
done
cmp native-profile/src/nfc/fm19511-uke.c drivers/misc/fm19511-uke.c
grep -Fx CONFIG_PM_SLEEP=y %{_uke_out}/.config
test -s %{_uke_out}/drivers/misc/fm19511-uke.o
llvm-nm -u %{_uke_out}/drivers/misc/fm19511-uke.o > native-generated/fm19511-undefined.txt
if grep -Eq ' (device_wakeup_enable|device_wakeup_disable|dev_pm_set_wake_irq|dev_pm_clear_wake_irq)$' native-generated/fm19511-undefined.txt; then exit 1; fi
grep -Eq ' pm_wakeup_dev_event$' native-generated/fm19511-undefined.txt
bash native-profile/tests/native-firewall-builtins-contract.sh native-profile/tests/native-firewall-contract.sh native-profile/configs/nfc-cdsp-reference.config
bash native-profile/tests/waydroid-network-built731.sh %{_uke_out} native-profile/configs/waydroid-network.config
bash native-profile/tests/nfc-cohort-config731.sh "$vi_config" native-generated/migration-manager-linked-waydroid/.config
test -s %{_uke_out}/drivers/hid/hid-nanosic-uke.o
test -s %{_uke_out}/drivers/remoteproc/qcom_q6v5_pas.o
test -n "$(find %{buildroot}/usr/lib/modules/%{krel} -type f -name 'hid-nanosic-uke.ko*' -print -quit)"

printf '%%s  %%s\n' a356b29e812917478125d512bc9740f0f95ad96131bc2eb0d2dd39137989a545 native-profile/src/boot/uke-pstore-dt.h \
    a6e07cdf0cdbf82f3c1ce935f7486600ad83e70c84b0686bcb50a4d28ab5a4d9 native-profile/tests/pstore-fdt731-contract.sh | sha256sum -c --strict --quiet -
cmp native-profile/src/boot/uke-pstore-dt.h boot-recipe/src/boot/uke-pstore-dt.h
cmp native-profile/tests/pstore-fdt731-contract.sh boot-recipe/tests/pstore-fdt731-contract.sh
bash native-profile/tests/pstore-fdt731-contract.sh
grep -aFq 'Uke ABL DT: using firmware ramoops layout' %{_uke_out}/arch/arm64/boot/Image
cmp native-profile/src/boot/uke-pstore-dt.h arch/arm64/kernel/uke-pstore-dt.h
test "$(grep -Fc 'ret = uke_pstore_graph(output);' arch/arm64/kernel/uke-abl.c)" = 1
grep -aqF 'max-reason' %{_uke_out}/arch/arm64/kernel/uke-abl.o
sha256sum -c --strict --quiet native-generated/nfc-cdsp-before-reference/historical-inputs.sha256
bash native-profile/tests/cdsp-pogo-toolchain-contract.sh native-generated/nfc-cdsp-before-reference/historical.config
bash native-profile/tests/cdsp-pogo-config-contract.sh native-generated/nfc-cdsp-before-reference/historical.config
bash native-profile/tests/governor-config-contract.sh native-generated/nfc-cdsp-before-reference/.config native-generated/nfc-cdsp-reference/.config
cmp native-profile/src/camera/eeprom/uke-front-eeprom-dt.h arch/arm64/kernel/uke-front-eeprom-dt.h
test -s %{_uke_out}/drivers/regulator/qcom-rpmh-regulator-uke.o
llvm-readelf -h %{_uke_out}/drivers/regulator/qcom-rpmh-regulator-uke.o | grep -F AArch64
# UKE_CAMERA_FULL7349_ADMISSION_BEGIN
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/boot/Image
# UKE_CAMERA_FULL7349_ADMISSION_END
test -s %{_uke_out}/drivers/nvmem/at24.o
llvm-readelf -h %{_uke_out}/drivers/nvmem/at24.o | grep -F AArch64
llvm-nm %{_uke_out}/drivers/nvmem/at24.o | awk '$NF=="at24_read" {found=1} END {exit !found}'
test -s %{_uke_out}/drivers/i2c/busses/i2c-qcom-cci.o
llvm-readelf -h %{_uke_out}/drivers/i2c/busses/i2c-qcom-cci.o | grep -F AArch64
llvm-nm %{_uke_out}/drivers/i2c/busses/i2c-qcom-cci.o | awk '$NF=="cci_probe" {found=1} END {exit !found}'
bash native-profile/tests/camcc-controller-linked731-check.sh.publication %{_uke_out} %{buildroot} '%{krel}'
bash native-generated/normal-camss-assets/check-camss-built-in735.sh %{_uke_out} '%{krel}' %{buildroot}
test -z "$(find %{buildroot} -type f -name '*camss-sm7675*' -print -quit)"
test -z "$(find %{buildroot} -type f \( -name '*camcc-native*' -o -name '*camcc-sm7675*' \) -print -quit)"
bash native-profile/tests/camera-sensor731-modules.sh %{_uke_out} %{buildroot} '%{krel}'
grep -Fx CONFIG_QCOM_GDSC=y %{_uke_out}/.config
test -s %{_uke_out}/drivers/clk/qcom/gdsc.o
llvm-readelf -h %{_uke_out}/drivers/clk/qcom/gdsc.o | grep -E 'Machine:.*AArch64'
bash native-profile/tests/touch-gesture-ack-package-contract.sh "$PWD" %{_uke_out}
bash native-profile/tests/ath11k-regulatory-status-package-contract.sh "$PWD" %{_uke_out}
bash native-profile/packaging/native/check-shipping-audio733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/check-avr-transaction733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/check-rproc-event733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/check-speaker-quad733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/check-proximity-input733.sh "$gravity_parent" %{_uke_out} linked
bash native-profile/packaging/native/check-rproc-count733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/prepare-mst-power-delivery733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/prepare-surround-full733.sh.publication "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/prepare-pcm-surround-full733.sh "$PWD" %{_uke_out} linked
bash native-profile/packaging/native/prepare-gravity-full733.sh.publication "$quaternion_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-quaternion-full733.sh.publication "$buffer_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh.publication "$heading_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-heading-full733.sh.publication "$proximity_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-proximity-abi-full733.sh.publication "$uke_native_parent" %{_uke_out} linked
charge_observe_parent=$(bash native-profile/packaging/native/charge-observe-legacy-view733.sh "$PWD")
charge_demand_parent=$(bash native-profile/packaging/native/charge-demand-legacy-view733.sh "$charge_observe_parent")
charge_standard_parent=$(bash native-profile/packaging/native/charge-standard-legacy-view733.sh "$charge_demand_parent")
battery_event_parent=$(bash native-profile/packaging/native/battery-event-legacy-view733.sh "$charge_standard_parent")
bash native-profile/packaging/native/prepare-charge-online-full733.sh.publication "$battery_event_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-battery-event-full733.sh.publication "$charge_observe_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-charge-standard-full733.sh.publication "$charge_demand_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-charge-demand-full733.sh.publication "$charge_observe_parent" %{_uke_out} linked
bash native-profile/packaging/native/prepare-charge-observe-full733.sh.publication "$PWD" %{_uke_out} linked
bash native-profile/tests/hardware1900-package-contract.sh "$PWD" %{_uke_out}
bash native-profile/tests/nfc-ir-v2-package-contract.sh %{_uke_out}
bash native-profile/tests/ssc-package-contract.sh %{_uke_out}
grep -Fx 'CONFIG_ANDROID_BINDER_IPC=y' %{_uke_out}/.config
grep -Fx 'CONFIG_ANDROID_BINDERFS=y' %{_uke_out}/.config
grep -Fx 'CONFIG_ANDROID_BINDER_DEVICES=""' %{_uke_out}/.config
grep -Fx 'CONFIG_MEMFD_CREATE=y' %{_uke_out}/.config
test -s %{_uke_out}/drivers/android/binder.o
test -s %{_uke_out}/drivers/android/binderfs.o
grep -Eq ' [tT] binder_init$' %{_uke_out}/System.map
grep -Eq ' [tT] init_binderfs$' %{_uke_out}/System.map
bash native-profile/tests/nfc-ir-package-contract.sh %{_uke_out}
bash native-profile/tests/memlat-package-contract.sh %{_uke_out}
uke_check_start=$SECONDS
bash native-profile/tests/kernel-hardening-config-contract.sh %{_uke_out}/.config
bash native-profile/tests/kernel-module-signatures-contract.sh "$PWD" %{buildroot}/usr/lib/modules/%{krel} %{buildroot}/usr/share/senemos/uke/%{krel}/module-signing.x509
test ! -e %{_uke_out}/certs/signing_key.pem

test -s %{buildroot}%{_docdir}/%{name}/%{krel}/README.md
test ! -e %{buildroot}%{_docdir}/%{name}/README.md
printf 'UKE_BUILD_STAGE package_checks elapsed_s=%d\n' "$((SECONDS-uke_check_start))"
bash native-hardware/packaging/native/prepare-native-hardware-full733.sh.publication "$uke_hwkm_parent" %{_uke_out} sealed
bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh.publication "$PWD" %{_uke_out} sealed
# UKE_CAMERA_FULL7346_HWKM_BEGIN
bash hwkm-early/packaging/native/prepare-hwkm-early733.sh.publication "$camera_full5_parent" %{_uke_out} sealed
# UKE_CAMERA_FULL7346_HWKM_END
bash qtee-information/packaging/native/prepare-qtee-information733.sh.publication "$PWD" %{_uke_out} sealed

# UKE_CAMERA_FULL7346_SEALED_BEGIN
sha256sum -c --strict --quiet camera-owner734-result/source.sha256 camera-owner734-result/retained.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-owner734-result/full-linked.sha256")
cmp %{_uke_out}/arch/arm64/boot/Image %{buildroot}/usr/lib/modules/%{krel}/vmlinuz
# UKE_CAMERA_FULL7346_SEALED_END
# Inherited installers compare the exact source record in the staging root.
# Publish the normal ABI's verified runtime record after those checks finish.
install -m644 native-generated/normal-source-composition.json %{buildroot}/usr/share/senemos/uke/%{krel}/source-composition.json
bash %{SOURCE398} %{_specdir}/senemos-uke-linux-kernel-mainline.spec %{buildroot} %{krel} %{normal_parent_copr}
%install
export SENEMOS_PUBLICATION_ABI='%{krel}'
printf '%%s  %%s\n' 549a5827f2cab21b45a4be5bb740bffb35a2306a1bc4f5dcdbcdc5e414bbab9b %{SOURCE409} 6b8e63a13d9968f656220294d0c018f1757aaf65052aca20eda7b7c4af4dbb08 %{SOURCE410} 6561c6944c4d773f86eebe88f1310e303a4ea7569bd2dc222d44e72d064380f5 %{SOURCE411} | sha256sum -c --strict --quiet -
dtbo_receipt=$(mktemp)
rpm2cpio %{SOURCE411} |
    cpio -i --quiet --to-stdout './usr/share/uke-kernel-migration-check/recovered-dtbo-fold/qualification.txt' > "$dtbo_receipt"
grep -Fxq 'Native ARM64 package metadata, all content attributes, exact predecessor replacement and restoration in isolated RPM database passed.' "$dtbo_receipt"
grep -Fxq '6b8e63a13d9968f656220294d0c018f1757aaf65052aca20eda7b7c4af4dbb08  install-normal-recovered-dtbo.sh' "$dtbo_receipt"
grep -Fxq '549a5827f2cab21b45a4be5bb740bffb35a2306a1bc4f5dcdbcdc5e414bbab9b  uke-senemos-dtbo-1.0-1.fc46.aarch64.rpm' "$dtbo_receipt"
rm -- "$dtbo_receipt"
bash %{SOURCE410} %{SOURCE409} %{SOURCE204} %{buildroot}
# UKE_CAMERA_FULL73410_INSTALL_BEGIN
sha256sum -c --strict --quiet camera-full73410-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full73410-result/full-linked.sha256")
front_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-front-stage73410
install -d "$front_support"
install -m644 %{SOURCE229} "$front_support/full-qualification.json"
install -m644 camera-full73410-result/*.sha256 "$front_support/"
for name in front-stage734 front-observed734;do
 install -d "$front_support/$name"
 install -m644 "$name-result/"{results.txt,qualification.json} "$front_support/$name/"
done
install -m644 front-stage734-result/{source.sha256,native-objects.sha256,disabled-results.txt} "$front_support/front-stage734/"
install -m644 front-observed734-result/profile.sha256 "$front_support/front-observed734/"
install -m644 camera-full73410/front-stage734/src/camera/front-stage734/{pre.sha256,post.sha256,late-stage.patch} "$front_support/front-stage734/"
# UKE_CAMERA_FULL73410_INSTALL_END
# UKE_CAMERA_ICC_HF_FULL734_INSTALL_BEGIN
icc_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-icc-hf734
install -d "$icc_support"
install -m644 camera-icc-hf734-result/{qualification.json,source.sha256,full-linked.sha256} "$icc_support/"
# UKE_CAMERA_ICC_HF_FULL734_INSTALL_END
# UKE_GUNYAH_WATCHDOG_FULL734_INSTALL_BEGIN
watchdog_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/gunyah-watchdog734
install -d "$watchdog_support"
install -m644 native-generated/gunyah-watchdog734/proof/usr/share/uke-gunyah-watchdog-source-check/{qualification.json,post.sha256} "$watchdog_support/"
install -m644 native-generated/gunyah-watchdog734/full-linked.sha256 "$watchdog_support/"
# UKE_GUNYAH_WATCHDOG_FULL734_INSTALL_END
# UKE_CAMERA_FULL7349_INSTALL_BEGIN
sha256sum -c --strict --quiet camera-full7349-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full7349-result/full-linked.sha256")
receive_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-front7349
install -d "$receive_support"
install -m644 %{SOURCE226} "$receive_support/full-qualification.json"
install -m644 camera-full7349-result/*.sha256 "$receive_support/"
for name in camss-lite734 phy-power734 csid-irq734 csid-stream734 front-eeprom734;do
 install -d "$receive_support/$name"
 install -m644 "$name-result/"{source.sha256,native-objects.sha256,results.txt,qualification.json} "$receive_support/$name/"
done
install -m644 camera-full7349/src/camera/front-eeprom734/{pre.sha256,post.sha256,activation.patch} "$receive_support/front-eeprom734/"
# UKE_CAMERA_FULL7349_INSTALL_END
# UKE_CAMERA_FULL7348_INSTALL_BEGIN
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-native7348-result/full-linked.sha256")
sha256sum -c --strict --quiet camera-native7348-result/source.sha256
native_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-native7348
install -d "$native_support"
install -m644 %{SOURCE223} "$native_support/full-qualification.json"
install -m644 camera-native7348-result/*.sha256 "$native_support/"
for name in odd parent;do
 install -d "$native_support/$name"
 install -m644 camera-$name'734-result/'{source.sha256,native-objects.sha256,results.txt,qualification.json} "$native_support/$name/"
 install -m644 camera-full7348/camera-$name'734/'{source-commit,SHA256SUMS} "$native_support/$name/"
done
install -m644 camera-parent734-result/passive-results.txt "$native_support/parent/"
# UKE_CAMERA_FULL7348_INSTALL_END
# UKE_CAMERA_FULL7347_INSTALL_BEGIN
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-rom-report734-result/full-linked.sha256")
sha256sum -c --strict --quiet camera-rom-report734-result/source.sha256
rom_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-rom-report734
install -d "$rom_support"
install -m644 %{SOURCE220} "$rom_support/full-qualification.json"
install -m644 camera-rom-report734-result/{source.sha256,parent-source.sha256,current-source.sha256,native-objects.sha256,reporter-results.txt,composition-results.txt,qualification.json,full-linked.sha256} "$rom_support/"
install -m644 camera-full7347/camera-rom-report734/{source-commit,SHA256SUMS} "$rom_support/"
# UKE_CAMERA_FULL7347_INSTALL_END
# UKE_CAMERA_FULL7346_INSTALL_BEGIN
camera_full5_parent=$(bash camera-full7346/camera-full5-legacy-view734.sh "$PWD")
camera_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-native734
install -d "$camera_support"
install -m644 %{SOURCE217} "$camera_support/full-qualification.json"
install -m644 camera-owner734-result/{source.sha256,retained.sha256,native-objects.sha256,owner-results.txt,rom-results.txt,startup-results.txt,floor-results.txt,composition-results.txt,caller-results.txt,qualification.json} "$camera_support/"
install -m644 camera-owner734-result/parent-camcc-sm7675.c "$camera_support/parent-provider.c"
install -m644 camera-full7346/camera-owner734/{source-commit,SHA256SUMS} "$camera_support/"
# UKE_CAMERA_FULL7346_INSTALL_END
# UKE_DISPLAY_FULL7345_INSTALL_BEGIN
display_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/display-handoff734
install -d "$display_support"
install -m644 %{SOURCE214} "$display_support/full-qualification.json"
install -m644 display-handoff734-result/{source.sha256,native-objects.sha256,native-results.txt,qualification.json,parent-uke-dispcc-votes.c} "$display_support/"
# UKE_DISPLAY_FULL7345_INSTALL_END
# UKE_SUPER_FULL7344_INSTALL_BEGIN
super_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/super-root734
install -d "$super_support"
install -m644 %{SOURCE211} "$super_support/qualification.json"
install -m644 super-root734-result/{source.sha256,native-objects.sha256,native-results.txt} "$super_support/"
install -m644 boot-recipe/lock.json "$super_support/boot-source-lock.json"
install -Dm755 %{_uke_out}/boot-image %{buildroot}/usr/lib/senemos/kernel-updates/%{krel}/boot-image
install -m644 %{_uke_out}/super-profiles.json %{buildroot}/usr/lib/senemos/kernel-updates/%{krel}/
# UKE_SUPER_FULL7344_INSTALL_END
# UKE_ABM_FULL7343_INSTALL_BEGIN
abm_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/abm734
install -d "$abm_support"
install -m644 %{SOURCE207} "$abm_support/qualification.json"
install -m644 abm734/src/display/{abm734-parent.sha256,abm734-post.sha256} native-generated/abm734-native-results.txt "$abm_support/"
# UKE_ABM_FULL7343_INSTALL_END
# UKE_STABLE734_FULL_INSTALL_BEGIN
build_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support
install -d "$build_support"
install -m644 %{_uke_out}/Module.symvers "$build_support/"
install -m644 %{_uke_out}/include/generated/{utsrelease.h,compile.h} "$build_support/"
install -m644 %{SOURCE202} "$build_support/qualification.json"
install -m644 native-profile/src/livepatch/uke-livepatch-20261115.pem "$build_support/"
# UKE_STABLE734_FULL_INSTALL_END
# UKE_CAMERA_FULL7346_VIEW_BEGIN
uke_hwkm_parent=$(bash camera-full7346/camera-hwkm-legacy-view7346.sh "$camera_full5_parent")
# UKE_CAMERA_FULL7346_VIEW_END
uke_native_parent=$(bash native-hardware/packaging/native/native-hardware-legacy-view733.sh "$uke_hwkm_parent")
install -Dm644 native-profile/README.md %{buildroot}%{_docdir}/%{name}/%{krel}/README.md
install -Dm644 %{SOURCE7} %{buildroot}%{_docdir}/%{name}-singleboot/SINGLEBOOT.md
install -Dm644 %{SOURCE8} %{buildroot}%{_licensedir}/%{name}-singleboot/LICENSE
install -d %{buildroot}/usr/share/senemos/uke %{buildroot}/usr/lib/senemos
cat > %{buildroot}/usr/share/senemos/uke/singleboot.json <<'EOF'
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
ln -s kernel-updates/%{krel}/userdata.img %{buildroot}/usr/lib/senemos/default-boot.img
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
bash native-profile/src/audio/desktop/install-policy.sh.publication '%{buildroot}' '%{krel}' '%{version}-%{senemos_build_release}u'
bash native-profile/packaging/native/prepare-surround-full733.sh.publication "$PWD" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-pcm-surround-full733.sh "$PWD" %{_uke_out} install '%{buildroot}'
install -m644 native-profile/SHA256SUMS native-profile/source-commit native-profile/README.md "$identity/"
install -m644 native-profile/source-composition.json %{_uke_out}/module-signing.x509 "$identity/"
jq -e --argjson normal_parent '%{normal_parent_copr}' --arg abi '%{krel}' --arg source_rev '%{senemos_build_release}' --arg rev '%{normal_rpm_release}' --arg parent '%{source_krel}' '
    select(.upstream_version=="7.3.5" and .rpm_revision==$source_rev and .kernel_release==$parent)
    | .publication={family:"senemos-uke-linux-kernel-mainline",parent_copr_build:11360575,normal_parent_copr_build:$normal_parent,audio_bsg_native_check_copr:11367541,audio_bsg_archive_sha256:"5837ce0c5a8902de2bae42a09e34f942c9b5df09afc8070b5028275b53bf810d",normal_touch_distinct_check_copr:11367713,normal_touch_distinct_archive_sha256:"a21fce194b00af6ae1bd760400e0fcf21f2d652a5fd0f6731234395468fa636f",touch_watchdog_check_copr:11367440,touch_watchdog_archive_sha256:"f05b7b80a073d5583972871af4e0631822f9b61147b5e9bfacc6d3bcc2f2b02c",fixed_cap_epoch_check_copr:11367291,fixed_cap_epoch_archive_sha256:"de582397521396819fe57dc4356162fef988b870b17d48fdeb7cff98ccb8a9c0",rgb_usb_attach_check_copr:11362629,ssc_accel_batch_check_copr:11365772,rgb_ssc_archive_sha256:"ec84360ce6335b4e285ced16f92720fc30bbfe8118e816ca0decda8105872d6c",fcc_observation_check_copr:11367029,rproc_wakeup_check_copr:11367147,fcc_rproc_archive_sha256:"deaac33f3aea860085447177864d8c136b1abc314d099c0e97557bd47290f150",battery_status_burst_check_copr:11366742,battery_status_burst_archive_sha256:"23686f0c6ddcc0d5780fef26ad04b10a35a9727c2e88bf8cfea784ea7240790f",gpi_combined_archive_sha256:"9a78ae2eb6a1b8d5ebf179cc53e7aa1d3cebd348c8b182699e7453aeea5c93f7",pstore_layout_check_copr:11366271,backlight_minimum_check_copr:11362478,pstore_header_sha256:"a356b29e812917478125d512bc9740f0f95ad96131bc2eb0d2dd39137989a545",ktz_oem_minimum_archive_sha256:"a867c77b9e0541c26fb44b0fdc4d6bd10b2e8339b62f7075803752f3fbe60c04",feedback_layout_check_copr:11366032,geni_cleanup_check_copr:11365942,feedback_geni_archive_sha256:"e7842ecb237472c4df8a67db6111a95ff7cc3c9686ee62235210cc800f41aecf",audio_transport_check_copr:11365888,charge_policy_check_copr:11365780,transport_charge_archive_sha256:"60094e1242e5295e529535522ce2bf022043a5ffe788cd987c70c6a797bded1c",recovered_dtbo_rpm_sha256:"549a5827f2cab21b45a4be5bb740bffb35a2306a1bc4f5dcdbcdc5e414bbab9b",recovered_dtbo_qualification_copr:11365790,root_probe_archive_sha256:"ec8089f869207cffa482a66f94c936070cffce9a566f95a93da9fb61e2112f92",observation_archive_sha256:"6a83498907f2c772b5222ba6edbacc611e766a1070b3d336a1a76183dcc849a0",ucsi_fixed_contract_archive_sha256:"51a999c7fec2ed0782fbae29018289cbae0105b35cf2baff35683883a7291564",usb_type_archive_sha256:"38341d486c2e5d369bcf9548b4b76f11aae34072710c4d6967a8508372c62da6",battery_limit_archive_sha256:"7eea819b3b5f8b9952bc6f2641a9708f4e0d94a3a5e2e55a21d443d4a7074cf8",charge_band_epoch_archive_sha256:"997925be73a2539ec0b05c3cae5e7cfe01ffbabc43cb6c42cc11a4f3803816d5",threshold_observation_archive_sha256:"0159e8c92f449c84cd80a18f34c76edfa4833e243d16523253920b45a43c4dac",display_archive_sha256:"f93e2bef07dae46800cd2729ace96ebb9cacc8db34b171988b57d48fb0c544b1",source_kernel_release:.kernel_release,source_rpm_revision:$source_rev,charge_observation_archive_sha256:"e402a1b6969008f8525947cb1e2d77efe37460673396ad3a5938213ad73c8be2",vi_diagnostic_archive_sha256:"b8e5f7f4e475f2d70ca3e0ab01883249dc471daee5eb670a04edd15d2510a46f"}
    | .publication += {hbr3_trial:true,hbr3_trial_check_copr:11368624,hbr3_trial_archive_sha256:"c757a4e1aaa9531d5c07aa3ff53b47a4fc694fb28ff64398084727206881e26d",pack_voltage_check_copr:11368497,pack_voltage_archive_sha256:"c1448ccd3c790aab1f00ce1da34e1c3e882b3acb2488187897b161b3680807c4"}
    | .publication += {detached_mux_retry_check_copr:11368876,detached_mux_retry_archive_sha256:"df46ad746cb2b65715570760dea24c8ea455fa7739f4087ac50158ac92befd71",hbr3_startup_recovery_check_copr:11368662,hbr3_startup_recovery_archive_sha256:"450881e6abcb7a6f63548c66f6b28e0f62b44dd1f43be84f053a969c5ab95c6b",dpu_optional_dspp_check_copr:11368711,dpu_optional_dspp_archive_sha256:"472b2fb86b3c3d485f15daaead5af2f2b5b3142cc57122f476ede5720fc9ca76"}
    | .publication += {ov08d10_reset_check_copr:11368979,ov08d10_reset_archive_sha256:"8726f3109396bd6cf9388c8c3c162066a928df5725cbb1a868ec0188e949109a"}
    | .publication += {front_vdig_demand_check_copr:11369315,mst_controller_pm_check_copr:11369258,mst_controller_pm_archive_sha256:"32f3662ba97bf4212d0428530c94bf6901f3dff43eefa1e28979f6ac424fd5db",front_vdig_demand_archive_sha256:"862de62ac0dbdac25dde1a478e7765936873f0237e7565e2b5f4b158fec7a4c4"}
    | .rpm_revision=$rev
    | .kernel_release=$abi' native-profile/source-composition.json > native-generated/normal-source-composition.json
proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$uke_native_parent")
heading_parent=$(bash native-profile/packaging/native/heading-legacy-view733.sh "$proximity_parent")
buffer_parent=$(bash native-profile/packaging/native/quaternion-buffer-legacy-view733.sh "$heading_parent")
quaternion_parent=$(bash native-profile/packaging/native/quaternion-legacy-view733.sh "$buffer_parent")
bash native-profile/packaging/native/prepare-gravity-full733.sh.publication "$quaternion_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-quaternion-full733.sh.publication "$buffer_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-quaternion-buffer-full733.sh.publication "$heading_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-heading-full733.sh.publication "$proximity_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-proximity-abi-full733.sh.publication "$uke_native_parent" %{_uke_out} install '%{buildroot}'
charge_observe_parent=$(bash native-profile/packaging/native/charge-observe-legacy-view733.sh "$PWD")
charge_demand_parent=$(bash native-profile/packaging/native/charge-demand-legacy-view733.sh "$charge_observe_parent")
charge_standard_parent=$(bash native-profile/packaging/native/charge-standard-legacy-view733.sh "$charge_demand_parent")
battery_event_parent=$(bash native-profile/packaging/native/battery-event-legacy-view733.sh "$charge_standard_parent")
bash native-profile/packaging/native/prepare-charge-online-full733.sh.publication "$battery_event_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-battery-event-full733.sh.publication "$charge_observe_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-charge-standard-full733.sh.publication "$charge_demand_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-charge-demand-full733.sh.publication "$charge_observe_parent" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-charge-observe-full733.sh.publication "$PWD" %{_uke_out} install '%{buildroot}'
bash native-profile/packaging/native/prepare-storage-config-full733.sh.publication "$PWD" %{_uke_out} install '%{buildroot}'
install -m644 senemos-adaptation/source-lock.json senemos-applied-patches.txt "$identity/"
install -Dm644 native-generated/POCO-Pad-X1-AudioReach-tplg.bin \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/sm7675/POCO-Pad-X1-AudioReach-tplg.bin
install -Dm644 native-generated/POCO-Pad-X1-HDMI-tplg.bin \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/sm7675/POCO-Pad-X1-HDMI-tplg.bin
install -Dm644 native-generated/fs19xx-scenario735/candidate.tplg \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/sm7675/POCO-Pad-X1-tplg.bin
# AudioReach derives this lookup from the unnormalized ASoC driver name.
install -d %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke%{version}-%{senemos_build_release}u
ln -s ../sm7675/POCO-Pad-X1-tplg.bin \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke%{version}-%{senemos_build_release}u/POCO-Pad-X1-tplg.bin
cmp native-generated/fs19xx-scenario735/candidate.tplg \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke%{version}-%{senemos_build_release}u/POCO-Pad-X1-tplg.bin
bash native-generated/normal-vi-linked/packaging/native/install-fs19xx-vi-topology735.sh \
    %{_uke_out}/.config native-generated/normal-vi-linked/accepted.conf native-generated/fs19xx-scenario735/candidate.tplg \
    %{buildroot}/usr/lib/firmware/%{krel}/qcom/sm7675 %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke%{version}-%{senemos_build_release}u
install -d %{buildroot}/usr/lib/firmware/%{krel}/qcom/uke
test -z "$(find %{buildroot} -type f \( -name '*.py' -o -name '*.pyc' -o -name 'python*' \) -print -quit)"
bundle=%{buildroot}/usr/lib/senemos/kernel-updates/%{krel}
mkdir -p "$bundle"
install -m644 %{_uke_out}/linux.img "$bundle/linux.img"
install -m644 %{_uke_out}/userdata.img "$bundle/userdata.img"
install -m644 %{_uke_out}/modules.sha256 "$bundle/modules.sha256"
install -m644 %{_uke_out}/boot-manifest "$bundle/manifest"
printf 'o82_private_color=5\n' >> "$bundle/manifest"
install -m644 %{SOURCE6} "$bundle/source-lock.json"
install -m644 %{uke_boot_userspace}/build-rpms.tsv "$bundle/build-rpms.tsv"
mkdir -p %{buildroot}/usr/share/licenses/%{name}-boot-%{version}-%{release}
cp -a %{uke_boot_userspace}/licenses/. %{buildroot}/usr/share/licenses/%{name}-boot-%{version}-%{release}/
cp -a boot-recipe/src/boot/licenses/. %{buildroot}/usr/share/licenses/%{name}-boot-%{version}-%{release}/

bash native-profile/tests/o82-profile-loader-contract.sh native-profile
bash native-profile/tests/o82-lutbus-contract.sh
bash native-profile/tests/o82-regdma-transport-contract.sh native-profile "$PWD"
bash native-profile/tests/o82-atomic-contract.sh native-profile "$PWD"
bash native-profile/tests/o82-atomic-package-contract.sh "$PWD" %{_uke_out}
bash native-hardware/packaging/native/prepare-native-hardware-full733.sh.publication "$uke_hwkm_parent" %{_uke_out} install '%{buildroot}'
bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh.publication "$PWD" %{_uke_out} install '%{buildroot}'
# UKE_CAMERA_FULL7346_HWKM_BEGIN
bash hwkm-early/packaging/native/prepare-hwkm-early733.sh.publication "$camera_full5_parent" %{_uke_out} install '%{buildroot}'
# UKE_CAMERA_FULL7346_HWKM_END
bash qtee-information/packaging/native/prepare-qtee-information733.sh.publication "$PWD" %{_uke_out} install '%{buildroot}'

install -Dm644 native-profile/src/audio/LICENSE.audioreach-topology "%{buildroot}%{_licensedir}/%{name}-%{version}-%{release}/LICENSE.audioreach-topology"

%files
%doc %{_docdir}/%{name}/%{krel}/README.md
%license COPYING
%license %{_licensedir}/%{name}-%{version}-%{release}/LICENSE.audioreach-topology

%files core
%dir /usr/lib/modules/%{krel}
/usr/lib/modules/%{krel}/vmlinuz
/usr/lib/modules/%{krel}/config
/usr/lib/modules/%{krel}/System.map
/usr/lib/modules/%{krel}/modules.builtin*
/usr/lib/modules/%{krel}/modules.order
/usr/share/senemos/uke/%{krel}/
/usr/lib/firmware/%{krel}/
%ghost %attr(0644,root,root) /usr/lib/firmware/%{krel}/qcom/uke/vpu30_2v.mbn
%dir /usr/share/alsa/ucm2/Qualcomm/sm7675
/usr/share/alsa/ucm2/Qualcomm/sm7675/*.conf
%dir /usr/share/alsa/ucm2/conf.d/sm7675
/usr/share/alsa/ucm2/conf.d/sm7675/*.conf
/usr/share/alsa/ucm2/Qualcomm/%{uke_audio_driver}/
/usr/share/alsa/ucm2/conf.d/%{uke_audio_driver}/
/usr/share/wireplumber/wireplumber.conf.d/75-uke-thp-not-camera.conf
/usr/share/wireplumber/wireplumber.conf.d/80-uke-microphone-array.conf
/usr/share/wireplumber/wireplumber.conf.d/95-uke-microphone-array-%{krel}.conf
%dir /usr/share/senemos/uke/audio
/usr/share/senemos/uke/audio/microphone-layout.json
%license /usr/share/licenses/uke-kernel-audio-%{krel}/LICENSE

/usr/lib/modules/%{krel}/kernel/
/usr/lib/modules/%{krel}/modules.alias*
/usr/lib/modules/%{krel}/modules.dep*
/usr/lib/modules/%{krel}/modules.devname
/usr/lib/modules/%{krel}/modules.softdep
/usr/lib/modules/%{krel}/modules.symbols*
/usr/lib/modules/%{krel}/modules.weakdep

/usr/lib/modules/%{krel}/dtb/

/usr/lib/senemos/kernel-updates/%{krel}/
%license /usr/share/licenses/%{name}-boot-%{version}-%{release}/

%files singleboot
%doc %{_docdir}/%{name}-singleboot/SINGLEBOOT.md
%license %{_licensedir}/%{name}-singleboot/LICENSE
/usr/lib/senemos/dtbo
%dir %{_docdir}/uke-senemos-dtbo
%doc %{_docdir}/uke-senemos-dtbo/formatter.json
%doc %{_docdir}/uke-senemos-dtbo/reference.json
%doc %{_docdir}/uke-senemos-dtbo/report.json
%license %{_licensedir}/uke-senemos-dtbo/NOTICE
/usr/share/senemos/uke/singleboot.json
/usr/lib/senemos/default-boot.img

%changelog
* Sat Nov 21 2026 Uke Linux Maintainers - 7.3.5-35
- Balance DisplayPort attachment power references and preserve the exact MST stream rate.
- Select distinct MST encoders during simultaneous connector validation.

* Sat Nov 21 2026 Uke Linux Maintainers - 7.3.5-34
- Check all proposed real-time CRTC bandwidth reservations together before accepting a display configuration.
- Use the DisplayPort MST payload slot limit during mode and color-depth selection.

* Sat Nov 21 2026 Uke Linux Maintainers - 7.3.5-33
- Validate QCOM GPI event-ring producer pointers and bound the reset-time stale-event scan.
- Compute DPU bandwidth and clock votes from the incoming visible planes and adjusted mode.

* Sat Nov 21 2026 Uke Linux Maintainers - 7.3.5-32
- Keep AUX operational for an attached MST hub after all streams stop.
- Propagate the result of the final DisplayPort training attempt and handle unread AUX status.
- Use the same RGB bandwidth and depth rules in MST mode enumeration and atomic validation.

* Sat Nov 21 2026 Uke Linux Maintainers - 7.3.5-31
- Prefer sink-advertised YCbCr 4:2:0 when RGB would fall below 8 bpc on SST.
- Allocate the MST max-bpc property before device registration.
- Keep virtual MST DDC adapters from enumerating the controller device tree.

* Sat Nov 21 2026 Uke Linux Maintainers - 7.3.5-30
- Register the fitted front camera digital supply without a boot proxy vote.
- Use the DisplayPort controller power reference for MST port detection.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-29
- Abort OV08D10 power-on and release resources when reset fails.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-28
- Retry one busy Type-C mux transition after an explicit detach.
- Retry HBR2 once after an early HBR3 link clock or PHY failure.
- Keep expected DPU mixer capacity refusals at debug level.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-27
- Embed the SM7675 HBR3 trial overlay in the Unstable build.
- Add a read-only battery voltage provider for speaker qualification.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-26
- Preserve Uke DSC resources for streams that require compression.
- Keep partial charge status coherent across battery and source changes.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-23
- Keep valid NT36532 frame repeats separate from firmware watchdog recovery.
- Keep the fixed charge band request in its verified settings generation.
- Trigger the RGB sequence on physical USB attachment.
- Share one native accelerometer sample across same-thread axis reads.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-22
- Expose the fitted charger FCC setting through a read-only query.
- Release the remote processor wakeup source after a duplicate crash report.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-20
- Use the built Linux version and RPM revision for the kernel ABI.
- Isolate the topology licence per installonly release.
- Preserve the signed GENI and GPI source changes.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-19
- Preserve the bootloader ramoops layout when the optional Linux reservation is unavailable.
- Restore the fitted KTZ8866 backlight minimum at the first lit step.
- Publish the cumulative normal 7.4.11 runtime ABI.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-18
- Decode the fitted packed speaker feedback without raising the gain ceiling.
- Clear completed GENI I2C DMA mappings before subsequent messages.
- Recognize the 7.4.10 runtime ABI in the boot and package admission checks.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-17
- Fold the verified DTBO payload into the normal singleboot package.
- Add protected feedback transport traces and fitted charging policy observations.

* Fri Nov 20 2026 Uke Linux Maintainers - 7.3.5-16
- Reduce root and battery queries and add protected feedback diagnostics.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-14
- Add gain-223 speaker feedback diagnostic with an independent normal runtime release.
- Restore guarded charging-state checks and expose fitted read-only gauge and authentication state.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-13
- Publish the current cumulative Linux sources as the normal kernel family.
- Use 7.4.5-senemos as the runtime ABI and retain build provenance.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-13
- Observe confirmed O82 panel state from the battery manager without an initramfs panel dependency.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-12
- Preserve ALSA state saving when amplifier diagnostic registers are restricted.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-11
- Report cached source PDO discovery, fitted fast charging mode and the APDO limit.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-10
- Ship the matching kernel, modules, DT and boot bundle under the existing core owner.
- Preserve the split names as versioned capabilities and retain installed fallback releases.
- Expose the fitted adapter identity and three OEM charging modes as guarded reads.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-9
- Publish the battery supply after coherent firmware identity reads.
- Preserve the existing SDP gate and expose the three fitted OEM USB source observations.

* Thu Nov 19 2026 Uke Linux Maintainers - 7.3.5-8
- Start the protected Uke feedback subgraph before playback.
- Keep the 223 boot volume and enable root-only OEM charger observations for Uke qualification.

* Thu Nov 19 2026 Uke contributors - 7.3.5-7
- Give Uke battery identity readers one shared initial firmware readiness budget.

* Thu Nov 19 2026 Uke contributors - 7.3.5-6
- Report protected FS19xx converter and data-out status through an on-demand read-only control.

* Thu Nov 19 2026 Uke contributors - 7.3.5-5
- Align protected speaker and VI subgraph directions with the AudioReach firmware ABI.
- Reuse the DMA-IOMMU aperture floor during Iris probe.
* Wed Nov 18 2026 Uke contributors - 7.3.5-3
- Refresh the cached USB-C source profile after a guarded connection recheck.
- Reject malformed source PDO segments before publishing the cached profile.

* Wed Nov 18 2026 Uke contributors - 7.3.5-2
- Use stock-sized AudioReach TDM parameter payloads for the speaker and VI endpoints.
- Expose cached USB-C PD contract metadata under the existing firmware policy.

* Wed Nov 18 2026 Uke contributors - 7.3.5-1
- Preserve cumulative Uke support on signed Linux 7.3.5.

* Wed Nov 18 2026 Uke contributors - 7.3.4-11
- Integrate early Plymouth, native watchdog, speaker shutdown and RGB demand handling.
# UKE_FS19XX_TELEMETRY734_CHANGELOG_BEGIN
- Bound speaker preset records and add on-demand DSP temperature diagnostics.
# UKE_FS19XX_TELEMETRY734_CHANGELOG_END

# UKE_CAMERA_FULL73410_HISTORY_BEGIN
* Tue Nov 17 2026 Uke contributors - 7.3.4-10
- Admit the read-only front gate after native interconnect tags and restored DT capacity.
- Qualify the unchanged helper against a board-only projection before linking the Image.

# UKE_CAMERA_FULL73410_HISTORY_END
# UKE_CAMERA_FULL7349_HISTORY_BEGIN
* Tue Nov 17 2026 Uke contributors - 7.3.4-9
- Admit the exact read-only front EEPROM route after controller boot qualification.
- Retain qualified lite VFE, scoped PHY supplies and CSID IRQ/stream lifecycle fixes.

# UKE_CAMERA_FULL7349_HISTORY_END
# UKE_CAMERA_FULL7348_HISTORY_BEGIN
* Tue Nov 17 2026 Uke contributors - 7.3.4-8
- Prepare local camera PLL parents before ROM decoding and retain the original odd postdivider field.

# UKE_CAMERA_FULL7348_HISTORY_END
# UKE_CAMERA_FULL7347_HISTORY_BEGIN
* Tue Nov 17 2026 Uke contributors - 7.3.4-7
- Preserve full6 and report the exact cached CRM ROM refusal before camera admission.

# UKE_CAMERA_FULL7347_HISTORY_END
# UKE_CAMERA_FULL7346_HISTORY_BEGIN
* Tue Nov 17 2026 Uke contributors - 7.3.4-6
- Admit firmware CRM through checked ROM, permanent IRQ ownership and inherited-vote synchronization, preserving cumulative full5.

# UKE_CAMERA_FULL7346_HISTORY_END
# UKE_DISPLAY_FULL7345_HISTORY_BEGIN
* Mon Nov 16 2026 Uke contributors - 7.3.4-5
- Keep the firmware MDP clock configuration until native takeover, preserving cumulative full4 and normal runtime clock parking.

# UKE_DISPLAY_FULL7345_HISTORY_END
# UKE_SUPER_FULL7344_HISTORY_BEGIN
* Mon Nov 16 2026 Uke contributors - 7.3.4-4
- Add explicit seed4 and read-only rescue boot profiles with qualified native callers and original Fedora initrd tools.

# UKE_SUPER_FULL7344_HISTORY_END
# UKE_ABM_FULL7343_HISTORY_BEGIN
* Mon Nov 16 2026 Uke contributors - 7.3.4-3
- Update CABC without cycling the powered O82 panel; keep the RGB desktop client outside lean rescue core.

# UKE_ABM_FULL7343_HISTORY_END
* Sun Nov 15 2026 Uke contributors - 7.3.4-2
- Add native VRR, battery LED events and signed livepatch support; physical qualification remains separate.

* Sun Nov 15 2026 Uke contributors - 7.3.3-28
- Add explicit once-only kernel QTEE TPM metadata discovery; preserve full27 features.
- Keep user ioctl restrictions, no TPM startup, no automatic firmware request.

* Sun Nov 15 2026 Uke contributors - 7.3.3-27
- Embed first-probe HWKM opt-in and retain qualified passive camera clocks.
- Preserve cumulative full26 features, source checks, signed modules and recovery.
- Keep hardware key, secure-boot, encrypted I/O and resume acceptance separate.

* Fri Nov 13 2026 Uke contributors - 7.3.3-26
- Add a root-only on-demand SSC counter reference for measured clock research.
- Retain all full25 hardware, configuration, checks and runtime package names.
- Keep acquisition-time, gravity-frame and physical admission closed.

* Fri Nov 13 2026 Uke contributors - 7.3.3-25
- Adopt complete native CAMCC resource ownership and preserve firmware refusal.
- Wait for real SSC streaming reports instead of replaying cached samples.
- Retain full24 checks through authenticated source views and seal actual ELFs.
- Keep physical camera, gravity frame and device acceptance separate.

* Wed Nov 11 2026 Uke contributors - 7.3.3-24
- Enable the qualified native filesystem and block encryption capability layer.
- Retain all other kernel settings,reference checks and protected223 features.
- Keep encrypted I/O,TEE key operations and encrypted boot unqualified.

* Wed Nov 11 2026 Uke contributors - 7.3.3-23
- Restore passive legacy protection reads and version explicit native observations.
- Preserve native demand capability,standard getters and the cumulative hardware baseline.

* Wed Nov 11 2026 Uke contributors - 7.3.3-22
- Refresh stale native protection snapshots on demand and preserve errors.
- Keep valid cache reads, the legacy guard and all cumulative hardware features.

* Wed Nov 11 2026 Uke contributors - 7.3.3-21
- Expose observed charge thresholds through standard power_supply getters.
- Preserve writer admission,all cumulative hardware features and recovery.

* Wed Nov 11 2026 Uke contributors - 7.3.3-20
- Forward native battery status events and retain reported zero cycles.
- Preserve fixed-cap controls,all cumulative hardware features and recovery.

* Wed Nov 11 2026 Uke contributors - 7.3.3-19
- Add an explicit fixed above-limit70/80 target reapplication.
- Preserve offline operation,quarantine,hardware features and recovery.

* Tue Nov 10 2026 Uke contributors - 7.3.3-18
- Identify the native proximity input ABI before IIO discovery.
- Preserve raw sensor values,firmware ownership,audio,config and recovery.

* Tue Nov 10 2026 Uke contributors - 7.3.3-17
- Expose admitted ROTV magnetic heading through the standard IIO channel.
- Share firmware demand and preserve raw quaternion ABI,audio,config and recovery.

* Tue Nov 10 2026 Uke contributors - 7.3.3-16
- Size quaternion scan storage using the real IIO repeat-four alignment.
- Preserve prior hardware, scalar/vector layouts, protected audio and A/B recovery.

* Tue Nov 10 2026 Uke contributors - 7.3.3-15
- Publish three firmware quaternion streams through standard atomic IIO reads.
- Preserve all prior hardware, protected audio, config and A/B recovery.

* Tue Nov 10 2026 Uke contributors - 7.3.3-14
- Add one native SSC gravity and linear acceleration stream with standard IIO axes.
- Retain protected audio, existing sensor channels, production config and A/B delivery.

* Tue Nov 10 2026 Uke contributors - 7.3.3-13
- Fix semantic UCM IDs and bounded eight-channel PCM transport.
- Correct media lengths while preserving protected quad outputs and gain223.

* Tue Nov 10 2026 Uke contributors - 7.3.3-12
- Render six/eight program channels to four protected internal speakers.
- Freeze amplifier work across system sleep and retain the quad fallback.

* Mon Nov 09 2026 Uke contributors - 7.3.3-11
- Deliver qualified per-stream MST depth and responsive saver CPU QoS.
- Preserve SST, audio protection, cumulative checks and recovery interfaces.

* Sat Nov 07 2026 Uke contributors - 7.3.3-10
- Deliver PCM periods independently of ordered GPR command reception.
- Drain reports before PCM release; retain compressed and capture paths.
- Preserve all cumulative features, protected223 and existing admission.

* Sat Nov 07 2026 Uke contributors - 7.3.3-10
- Retain feedback through the finite muted APM STOP completion window.
- Publish configured mode after all four DAC mute readbacks complete.
- Preserve gain223, startup checks, all faults and cumulative features.

* Sat Nov 07 2026 Uke contributors - 7.3.3-10
- Classify healthy idle atomically while retaining output fault containment.
- Expose read-only O82 VRR floor ABI and both parameter type fields.
- Preserve complete12217, calibrated protection and automatic A/B staging.

* Sat Nov 07 2026 Uke contributors - 7.3.1-12217
- Mute output while retaining VI transport until protected DSP STOP completes.
- Preserve full12216 features, calibration/gain, failure erasure and automatic staging.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12216
- Accept the fitted GPR client byte and wait once for initial private readiness.
- Preserve full12215 DMA/DT, transport lifetime, protection, cumulative features and staging.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12215
- Accept the four defined GPR client-data bits while retaining true reserved-bit refusal.
- Preserve full12214 DMA/DT, transport lifetime, protection, cumulative features and staging.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12214
- Admit only the permanent Uke configuration supplier to the existing audio DMA context.
- Preserve full12213 final DT, transport, protection, cumulative features and staging.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12213
- Compose protected audio DMA after the selected native overlay.
- Preserve full12212 transport, protection, cumulative features and staging.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12212
- Transport whole protected configuration through dedicated shared memory.
- Preserve cumulative features, gain223, private identity and updater101 staging.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12211
- Negotiate remote intents for synchronous static APM configuration.
- Preserve complete12210, protected223 records and asynchronous transport.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12210
- Connect the speaker frontend before the protected MFC/RX chain.
- Retain complete12209 and all protected223/VI/IMCL and boot-header gates.
- Require updater101 for independent matching-array CRC maintenance.

* Fri Nov 06 2026 Uke contributors - 7.3.1-12209
- Select explicit bootloader compatibility metadata for alternating slots.
- Retain canonical zero-header support, protected223 and complete12207 hardware.
- Require updater100 for the corrected inactive checkpoint write barrier.

* Thu Nov 05 2026 Uke contributors - 7.3.1-12207
- Scope audio OPEN cleanup and retain unpublished CRM quarantine across s2idle.
- Preserve protected223 and every cumulative feature/admission gate.

* Thu Nov 05 2026 Uke contributors - 7.3.1-12206
- Retain complete12204 and all qualified native sensor, Hall, manager and protected223 additions.
- Preserve camera/HDR admission, automatic staging and persistent local preferences.

* Thu Nov 05 2026 Uke contributors - 7.3.1-12204
- Retain complete12203 and all qualified cumulative peer contributions.
- Restore exact OEM GCC camera configuration gates; keep physical admission separate.

* Thu Nov 05 2026 Uke contributors - 7.3.1-12203
- Retain complete12101 with touch, memory/v5, geometry and GMU corrections.
- Include qualified SSC transactions, CDSP ACTLR and OEM CAMCC gate order.
- Retain speaker admission, seamless staging and the local rollback preference.

* Wed Nov 04 2026 Uke contributors - 7.3.1-12101
- Preserve the complete11003 feature set and qualified SSC observations.
- Record existing CAMCC probe phases and gate readbacks without extra MMIO.
- Retain physical admission gates, seamless staging and local rollback choice.

* Wed Nov 04 2026 Uke contributors - 7.3.1-12101
- Preserve the qualified 11003 camera, NFC, networking, color and power sources.
- Expose read-only SSC discovery counts and generation-scoped failure stages.
- Retain seamless staging and the persistent local rollback preference.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-11003
- Preserve qualified CDSP/pogo, display color and read-only RTC admission.
- Leave NFC wake source and wake IRQ lifetime with the I2C core.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-7603
- Retain the isolated 7200 graph and add guarded CDSP and pogo transport.
- Keep firmware provisioning and physical acceptance separate.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-7200
- Isolate camera boot admission in an explicitly selected unstable family.
- Exclude the ordinary kernel family and provide the selected userdata profile.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-6000
- Admit exact front GENI transport and a private read-only EEPROM provider.
- Retain shared VIO constraints and contain unported sensor/capture nodes.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-6000
- Add explicit read-only EEPROM voltage ownership and failure containment.
- Preserve native CAMCC/CCI and keep EEPROM and sensor activation separate.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-6000
- Initialize every supported CCI completion before controller reset and IRQ.
- Preserve guarded CAMCC, native CAMSS and the complete retained native cohort.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-6000
- Link permanent Uke CAMCC with read-only CRM mode admission.
- Activate only the controller graph and contain unported OEM camera consumers.
- Preserve the secure RTC/SSC parent and keep full camera acceptance outstanding.

* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-6000
- Qualify CAMCC per-clock voltage callbacks and retained fault state.
- Compile GDSC controller-PM support without opting in any domain or activating camera DT.

* Wed Nov 04 2026 Uke contributors - 7.3.1-5000
- Use OEM acknowledged gesture setters without extra diagnostic queries.
- Retain coordinate readback, mandatory errors and the complete3000 cohort.
- Require actual-old sequence/query failures and corrected native checks.

* Wed Nov 04 2026 Uke contributors - 7.3.1-3000
- Report converted ath11k country status before logging and in refusals.
- Preserve regulatory decisions and the complete qualified2700 cohort.
- Require actual-old diagnostic failures, sanitizer and full module checks.

* Wed Nov 04 2026 Uke contributors - 7.3.1-2700
- Declare existing cached WCD939x controls read-only with valid ranges.
- Retain the complete1900 cohort and qualified SSC large reports.
- Require actual-old access/range failures, real getters and native module checks.

* Wed Nov 04 2026 Uke contributors - 7.3.1-1900
- Retain adaptive L3 capacity, secure RTC, SSC temperature and NFC infrared.
- Gate SSC on the bound ADSP supplier and link separate DPU REGDMA resources.
- Verify the resulting modules and both supplier DT resource tuples.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1800
- Bound adaptive L3 map requests to provider-admitted OEM points.
- Preserve transport/PM errors, strict provider checks and the complete1710 cohort.
- Compute config provenance from retained bytes and record the exact parent.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1710
- Combine native SSC sensor temperature with qualified NFC tag and IR updates.
- Preserve the millicelsius ABI, tag events and read-only memory access.
- Retain supplier variants, MEMLAT, touch recovery and Binder support.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1600
- Add exact Uke firmware admission and verified secure RTC offset persistence.
- Refuse uninitialized RTC calendars without changing PMIC time or SDAM.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1500
- Bind firmware-owned Uke SSC sensors to the native QMI/IIO consumer.
- Require exact API metadata and verify complete module linkage.
- Retain supplier variants, MEMLAT, touch recovery and Binder support.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1303
- Enable built-in Binder IPC and binderfs in the normal ARM64 kernel.
- Retain release1301 drivers, suppliers, touch recovery and boot policy.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1301
- Permit one verified native touch recovery per powered lifecycle.
- Re-arm on panel/PM restoration and expose value-free diagnostic counters.

* Tue Nov 03 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1300
- Select either O82 native panel and its NT36532 supplier at early boot.
- Validate the complete PMIC inventory before admitting PM8010.
- Check both DSI suppliers and retain foreign-panel refusal coverage.
- Require native NFC and infrared access with verified provider aliases.
- Sample OEM LLCC/L3 latency maps through native perf and ICC providers.

* Mon Nov 02 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1011
- Retain installed1010 drivers and scope local video firmware to the new kernel ABI.
- Require image-copy-free inactive-slot delivery without requesting reboot.

* Sun Nov 01 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1003
- Preserve the requested 30 Hz O82 floor and zero-brightness first frame.
- Retain the installed release116 power, startup and matching-family inputs.

* Sun Nov 01 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-115
- Encode the standard initial console in one deterministic source-built cpio.
- Preserve early-user files, permissions, symlinks and regular-file hardlinks.
- Describe policy-gated automatic slot staging and the absence of automatic reboot.

* Sun Nov 01 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-114
- Backport upstream sorting of combined LPASS RX/WSA register defaults.
- Retain all register values, cache types and release113 warning corrections.

* Sun Nov 01 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-113
- Check for the optional LLCC window before mapping it.
- Use the current per-CPU system queue for amplifier delayed work.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-106
- Make guarded automatic boot staging the singleboot package contract.
- Require the updater whose default enables verified inactive-slot delivery.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-105
- Deliver the kernel-owned microphone array through the requested unstable channel.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-104
- Correct the gain schema unit suffix and validation path before kernel compilation.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-103
- Apply bounded DT microphone gains before codec power-up, with register rollback on errors.
- Deliver one named four-channel input and matching desktop data with the kernel.
- Preserve legacy audio data and version new policy files for parallel-kernel rollback.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-102
- Preserve contiguous codec-DMA microphone IDs through the frontend converter.
- Require the corrected raw-channel capability for desktop capture.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-101
- Admit the unmodified TX negative-control source with its existing sign warning.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-100
- Track each TX decimator independently and mute every selected capture channel.
- Gate shared microphone desktop profiles on the corrected capture lifecycle.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-16
- Preserve selected 1/2/4-channel capture at 48 kHz S16_LE.
- Require exact contiguous TX decimator counts and masks matching the DMA format.
- Advertise the bounded microphone capability in the running ALSA card components.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-13
- Add the four OEM analog input/bias routes and native ADC output bridges.
- Keep strict mono admission and qualify the remaining inputs separately.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-10
- Match the 56-byte AudioReach read-completion V2 ABI and timestamp layout.
- Keep strict reply-size, status, token, address and data-size checks.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-9
- Match the component minimum to the restricted Uke mono capture frontend.
- Preserve other cards, graphs and playback limits; physical capture remains pending.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-6
- Connect mono capture to the actual native WCD939x ADC1 output widget.
- Reject the incompatible OEM aggregate output in the prepared-source FDT check.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-5
- Retain the release4 profile and add guarded mono microphone capture.
- Preserve four-channel speaker and stereo DisplayPort paths; hardware testing remains pending.

* Sat Oct 31 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-4
- Admit the optional Uke PM8010 N using validated firmware population and resources.
- Preserve populated variants, generic SPMI errors and the accepted rollback slot.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-3
- Admit 7.3.1 in the retained alternate KMS compile check without changing drivers.
- Check actual release admission before the full build with a shell-only fixture.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-2
- Bind the native stable port to the exact published 122-patch adaptation queue.
- Preserve the separate canonical 127-patch source profile and its provenance.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1
- Move to signed upstream Linux 7.3.1 with the reviewed Uke patch queue.
- Retain final DNF singleboot staging and the accepted rollback slot.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-73
- Require final DNF singleboot staging and preserve the accepted rollback slot.
- Rebuild the exact release-60 driver sources with a distinct module ABI.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-60
- Preserve the reviewed drivers and update stop-proof regression fixture models.
- Run final-source AVR and video-disable contracts before kernel compilation.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-59
- Route boot RPM hooks through the guarded installed-profile transaction.
- Retain the reviewed scanout sources with a fresh kernel and signing identity.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-58
- Retain scanout and writeback pins until completion is proved.
- Check timer flush ordering, failed teardown and destination ownership in COPR.

* Fri Oct 30 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-57
- Unwind partial KMS initialization and drain display producers before teardown.
- Verify actual failure and concurrent-withdrawal paths in COPR.

* Fri Oct 30 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-56
- Keep color updates on the encoder's reserved control blocks and clear stale resources.
- Preserve caller modeset permission and validate the actual paths in COPR.

* Fri Oct 30 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-54
- Run the actual WLAN power-sequence fixture with independently managed storage.
- Validate the complete public source recipe on the COPR source worker.

* Fri Oct 30 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-53
- Require matching module signatures and retain only the build's public certificate.
- Enable integrity lockdown, FORTIFY, hardened usercopy, Yama and restricted logs.
- Verify every packaged module and reject unsigned, tampered and wrong-key controls.

* Fri Oct 30 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-52
- Install documentation under the exact kernel release so retained kernels can coexist.
- Mark the selection package as install-only alongside its matching payloads.

* Thu Oct 29 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-49
- Hold DTO force ACK through stream setup and release it before video starts.
- Quiesce the SM7675 DTO before pixel-clock shutdown, including failed enables.
- Check actual ACK register sequencing, clock-domain guards and stream cleanup.

* Thu Oct 29 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-48
- Match OEM external-stream timing control in the existing SM7675 setup path.
- Check compressed/plain programming and unrelated-bit preservation in the real packet fixture.

* Thu Oct 29 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-47
- Trigger continuous PPS transmission with the OEM flush bit and clear stale one-shot mode.
- Check the actual flush register with both initial modes and unrelated bits retained.
- Use arithmetic three-byte line padding and model kernel power-of-two alignment correctly.

* Thu Oct 29 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-46
- Program matching active and display data windows for compressed DisplayPort streams.
- Check real interface timing registers at FHD, QHD and UHD while retaining O82 timing coverage.

* Thu Oct 29 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-45
- Program DSC packetizer words at eight bits per component while retaining PPS input depth.
- Force complete CRTC programming when selected stream packing or DSC parameters change.

* Thu Oct 29 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-44
- Hold the DRM device across attached DSC requests and refuse missing/unregistered bindings.
- Stop policy notifications and receiver monitoring before component teardown.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-43
- Recompute SST admission after training negotiates a lower lane count or rate.
- Preserve DSC eligibility for a bandwidth retry instead of latching a protocol fault.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-42
- Negotiate attached DSC policy through atomic state and DRM link-status recovery.
- Check receiver enable readback and monitor link, decoder and FEC state.
- Retain a failed-compression latch and separate source from physical acceptance.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-41
- Select the proposed upstream GEM nonblocking-reclaim control for Uke latency.
- Preserve inactive eviction and swap, and report completed shrinker progress.
- Retain VP9/BCL safeguards; the THP-only release40 trial was canceled.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-40
- Restrict the default transparent-hugepage policy to advised mappings.
- Reduce measured reclaim stalls during loaded internal-panel transitions.
- Retain release-39 VP9 and release-38 BCL safeguards and separate device gates.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-39
- Recycle valid empty VP9 non-display capture buffers in both output orders.
- Retain corrupt, overflow, firmware ownership and queue submission errors.
- Keep release-38 BCL protection and separate package from device validation.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-38
- Return ENODATA for an empty PM7550BA current ADC sample without renewing its cache.
- Preserve valid current samples, firmware thresholds and other PMIC descriptors.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-37
- Add native PM7550BA BCL hwmon with exact Uke revision and resource admission.
- Preserve unavailable voltage samples and serialize alarm work/wake cleanup.
- Backport the matching standard hwmon emergency attributes and ABI documentation.
- Retain existing thermal references; MEMLAT/CDSP/microphone acceptance remains open.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-36
- Bound the SM7675 ICC boot floor to its firmware LUT capacity.
- Preserve strict rejection of real client overvotes and existing platforms.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-35
- Use exported OF CPU lookup with balanced references for modular LLCC counters.
- Admit the exact OEM NFC L7E provider while retaining POCO-only tag transport.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-34
- Integrate the running release-33 audio and native touch source fixes.
- Preserve paired CPU/L3 bandwidth admission and complete-path OPP recovery.
- Add the count-only SM7675 LLCC perf provider with exclusive per-CPU events.
- Use a distinct tuple for the combined source lineage.

* Wed Oct 28 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-33
- Admit exact CPU/LLCC monitor resources with both OEM primary and L3 OPP votes.
- Preserve existing GEM requests while adding AMC/WAKE-only monitor votes.
- Use the shared L3 page and existing CPUfreq clock pair; reject unmet L3 floors.
- Retain OPP rollback/retry guards and require distinct physical acceptance.
* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-33
- Preserve held touch identities and qualify coherent new contact groups.
- Retain interior electrode coordinates and filter single-contact patch roll.
- Keep the matched release-31 audio corrections and reviewed L3/OPP safeguards.
- Original KDE and Qt remain unchanged; desktop cancellation and Focus input acceptance remain open.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-32
- Restore all owned OPP bandwidth requests after a failed multi-path vote.
- Retain rollback uncertainty and retry incomplete OPP/BWMON cached targets.
- Own the bandwidth snapshot with its paths and propagate allocation failures.
- Keep CPU/LLCC DT admission and physical acceptance open.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-31
- Reject invalid native L3 clocks and zero/descending frequency tables.
- Retain native frequency width and unwind failed ICC link allocation.
- Exercise actual L3 probe/set/remove ownership and errors during preparation.
- Paired CPU/LLCC votes, multi-path OPP recovery and physical acceptance remain open.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-30
- Derive native DDR BWMON OPPs from exact Uke frequencies and byte units.
- Preserve existing MC requests while adding AMC/WAKE-only monitor votes.
- Recover owned counter-read faults without committing a failed sample.
- CPU/LLCC secondary L3 voting and physical bandwidth/lifecycle checks remain open.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-29
- Restore the Cliffs NSP/crypto suppliers and two/three-rail proxy ownership.
- Preserve PAS stop errors and prepare target shutdown before client removal.
- Track each proxy enable reference when bulk rollback can itself fail.
- Retain real Sysmon ACKs and test retry and legacy paths during source preparation.
- Native CDSP activation and physical lifecycle acceptance remain unqualified.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-28
- Restore MDT, FastRPC buffer and remote transport lifetime guards in the 7.3 source queue.
- Bound ELF32 metadata copies and admit firmware geometry before PAS operations.
- Run actual-code host fault and sanitizer checks during source preparation.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-27
- Apply reset, pin and supply dependencies to the Type-C USBSS module.
- Retain the separate fixed USB2 driver dependency scope and check both real Kconfig stanzas.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-26
- Preserve the last applied BWMON bandwidth after failed OPP transactions.
- Exercise actual IRQ-thread vote errors, retries, OPP references and rearming on the host.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-25
- Reuse the reviewed LPASS providers and coordinated codec reset with the current speaker graph.
- Keep one exact SM7675 pin provider and preserve the speaker TDM mux slots.
- Preserve codec supplier errors and release partial reset children before power-down.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-24
- Map the admitted Cliffs MCQ configuration, operation and status regions separately.
- Bound capability-derived queues and unwind mapping failures before SDB fallback.
- Retain native main-IRQ completion handling and poll-queue exclusion.
- Preserve working SDB buffers and queue metadata until all MCQ DMA allocations commit.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-23
- Connect the exact firmware-initialized Uke RNG to the upstream TRNG driver.
- Admit the exact UFS ICE/HWKM resources and retain the native host clock/power path.
- Require matching resources and retain disabled or unqualified hardware paths.

* Tue Oct 27 2026 Uke Linux project <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-22
- Preserve SKU identity, report the processor and LPDDR5X, and describe SSC-owned sensors.
- Add the POCO-only FM19511 tag transport and Uke infrared through upstream LIRC.
- Remove unreferenced panel and false fingerprint templates; physical acceptance remains pending.

* Tue Oct 27 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-21
- Contain FS19xx clock, thermal, register and stream-lifecycle failures.
- Enforce the uncalibrated volume ceiling and propagate invalid AudioReach setup.
- Require the combined-card desktop policy; microphone capture remains unavailable.

* Mon Oct 26 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-18
- Process Uke THP matrices in kernel input with a live baseline and tracked multitouch slots.
- Read touch identity, dimensions and shared electrode mapping from DT; retain lost-IRQ recovery.
- Require native boot acceptance support and run input/lifecycle fixtures in the RPM build.
* Mon Oct 26 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-17
- Report touchscreen coordinates through native input and load shared model firmware directly.
- Remove the matched userspace touch processor from the kernel payload.
* Mon Oct 26 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-16
- Add two-stream RGB8 SDR MST with payload and shared-link failure cleanup.
- Bound DP training by negotiated Type-C lanes and preserve unchanged IRQ routing.

* Mon Oct 26 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-15
- Require a fresh FEC receiver event before admitting compressed DisplayPort.
- Exercise stale detection, failed status clearing and actual compressed TU calculations.

* Mon Oct 26 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-14
- Add default-off RGB DSC with checked FEC, bounded PPS registers and atomic resource state.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-13
- Drain serialized battery requests before marking the Uke transport suspended.
- Keep ambiguous delivery blocked and test the in-flight reply during suspend.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-12
- Keep initialized touch firmware for gesture entry after panel blanking.
- Enforce the advertised downstream HDMI TMDS budget for DP color selection.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-11
- Add checked gesture retention and selective lid-open dispatch for s2idle wake trials.
- Preserve the release-10 display, video, AUX and ELD changes.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-10
- Notify the registered Uke DP PCM ELD control when its cached bytes change.
- Retain the reviewed video prerequisites and receiver diagnostic interface.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-9
- Expose the standard DP AUX interface for receiver capability diagnostics.
- Retain the video implementation and reviewed OEM video configuration gates.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-8
- Restore the exact OEM video configuration gates before GCC registration.
- Propagate both register-write failures; retain release-6 native video integration.
- Keep the separate Main10 source work and physical codec acceptance open.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-6
- Integrate the checked native Cliffs Iris, VIDEOCC and shared SMMU path.
- Preserve the published release-4/5 display, USB and RGB source changes.
- Require private firmware before codec registration; target acceptance remains open.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-5
- Validate the registered LED device name instead of its optional input name.
- Cover the RGB supplier probe with NULL-name and identity refusal fixtures.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-4
- Keep the single internal and external Uke pipelines on separate CRTCs.
- Prefer the spare color mixer and preserve another stream's DSPP ownership.
- Bound UCSI debugfs responses to the negotiated protocol payload size.
- Own the RGB LED through a kernel consumer with battery and camera policy.
- Provide bounded color-test and HEX control ioctls without changing LPG electrical limits.
- Refuse competing multicolor sysfs writes while the consumer owns the LED.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-3
- Keep the temporary framebuffer out of the native DSI connector namespace.
- Use the SM7675 catalog mixer width for uncompressed display topology.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-2
- Integrate admitted PMXR2230 torch/RGB providers and bounded flash cleanup.
- Expose real torch brightness steps without raising the current ceiling.

* Sun Oct 25 2026 Senemos Contributors <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-1
- Prepare the matched normal and userdata family from the reviewed Linux 7.3 port.
- Initialize DSI and DP connector states through the Linux 7.3 factory.
- Preserve guarded activation and parallel module packaging.

* Sun Oct 25 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-12
- Carry the reviewed USB/DP routing, audio, HDR and lane-ceiling changes from 7.2.12.
- Retain the WLAN lifetime fix, early console and bounded boot observations.
- Preserve Linux 7.3 API adaptations and the non-activating unstable singleboot tuple.

* Sat Oct 24 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.3.0-11
- Avoid blocking optional SMMU fault capture behind GPU recovery's mutex.
- Check actual capture and fault-completion lock-cycle behavior before building.
- Use the buffered touch source exporter and first-valid-frame readiness.
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
