%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}
%global _source_filedigest_algorithm 8
%global _binary_filedigest_algorithm 8
%global senemos_build_release 1.40
%global krel %{version}-senemos.%{senemos_build_release}
%global _uke_jobs %{?_smp_build_ncpus}%{!?_smp_build_ncpus:4}
%global _uke_out %{_topdir}/kernel-out
%{!?uke_boot_userspace:%global uke_boot_userspace %{_topdir}/boot-userspace}

Name: senemos-uke-linux-kernel-mainline
Version: 7.2.9
Release:        %{senemos_build_release}%{?dist}
Summary: Senemos mainline kernel build candidate for Xiaomi Uke
License: GPL-2.0-only
URL: https://github.com/MCC45TR/senemos-uke-kernel-mainline
Source0: linux-%{version}.tar.xz
Source1: senemos-uke-adaptation-%{version}.tar.xz
Source2: linux-%{version}.tar.sign
Source3: linux-stable.asc
Source4: gpr-domain-contract.sh
Source5: cpucp-mailbox-contract.sh
Source6: slim-startup-contract.sh
Source7: battery-protocol-contract.sh
Source8: firmware-backlight-contract.sh
Source9: usb-charger-readiness-contract.sh
Source10: qup-interconnect-contract.sh
Source11: adreno-lifecycle-contract.sh
Source12: cpu-epss-contract.sh
Source13: sysfb-damage-contract.sh
Source14: serial-power-budget-contract.sh
Source15: senemos-uke-boot-recipe.tar.xz
Source16: boot-payload.json
ExclusiveArch: aarch64
BuildRequires: bash bc bison flex clang llvm lld make gcc gcc-c++ perl
BuildRequires: elfutils-libelf-devel openssl-devel ncurses-devel
BuildRequires: rsync tar xz zstd gzip cpio kmod git-core jq gnupg2 dtc
BuildRequires: dracut systemd systemd-udev util-linux coreutils grep sed findutils binutils ripgrep
Requires: %{name}-core = %{version}-%{release}
Requires: %{name}-modules = %{version}-%{release}
Requires: %{name}-dtbs = %{version}-%{release}
Requires: %{name}-boot = %{version}-%{release}

%description
Uke/SM7675 source-build candidate. Package and compile validation do not
establish tablet boot or hardware support. Firmware and boot routing are
provided by the matched boot package. Automatic writes require explicit local
configuration and preserve Android A and the Linux partition layout.

%package core
Summary: Senemos Uke ARM64 kernel Image and build identity
Provides: installonlypkg(kernel)
Provides: kernel-uname-r(%{krel})

%description core
The EFI-enabled ARM64 Image, configuration and System.map for Senemos Uke.

%package modules
Summary: Modules matching the Senemos Uke kernel
Requires: %{name}-core = %{version}-%{release}
Requires: kmod
Provides: installonlypkg(kernel)

%description modules
Rebuilt AArch64 modules from the same source and configuration as Image.

%package dtbs
Summary: Independent Uke compile-stage device tree
Requires: %{name}-core = %{version}-%{release}
Provides: installonlypkg(kernel)

%description dtbs
Uke-specific CPU, interrupt and static reservation description. The future
UEFI handoff must supply exact-profile RAM and dynamic reservations. This
device tree is not physically accepted and unreviewed peripherals are disabled.

%package boot
Summary: Matched stock-ABL boot image and module inventory for Xiaomi Uke
Requires: %{name}-core = %{version}-%{release}
Requires: %{name}-modules = %{version}-%{release}
Requires: %{name}-dtbs = %{version}-%{release}
Requires: uke-kernel-update >= 0.1.0-12
Provides: installonlypkg(kernel)

%description boot
Kernel-only Android boot v4 image for boot_b and PARTLABEL=linux. It embeds the
same rebuilt modules as the matching RPM tuple. The native updater validates
the bundle and preserves rollback bytes before writing. It does not reboot.
The userdata layout is not supported by this package.

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
tar -xJf %{SOURCE15}
cmp boot-recipe/lock.json %{SOURCE16}
while IFS="$(printf '\t')" read -r path expected; do
    case "$path" in /*|*..*) exit 1;; esac
    test "$(sha256sum "boot-recipe/$path" | cut -d ' ' -f1)" = "$expected"
done <<EOF
$(jq -er '.source_assets[] | [.path,.sha256] | @tsv' %{SOURCE16})
EOF
mkdir -p %{_topdir}/abl-dt
bash boot-recipe/src/boot/prepare-abl-source.sh "$PWD" %{_topdir}/abl-dt

%build
%if !0%{?uke_package_only}
export ARCH=arm64 LLVM=1
export KBUILD_BUILD_USER=senemos KBUILD_BUILD_HOST=uke-builder
export SOURCE_DATE_EPOCH=$(jq -er '.source_date_epoch | numbers' senemos-adaptation/source-lock.json)
export KBUILD_BUILD_TIMESTAMP="$(date -u -d "@$SOURCE_DATE_EPOCH" '+%%Y-%%m-%%d %%H:%%M:%%S UTC')" KBUILD_BUILD_VERSION=1
# A killed fixdep can leave a partially written .cmd file. Preserve completed
# objects and discard only dependency records that no longer parse as Make.
if test -d %{_uke_out}; then
    find %{_uke_out} -type f -name '.*.cmd' | while IFS= read -r record; do
        if ! make -s -rR -f "$record" --eval '.PHONY: senemos_parse_check' \
            --eval 'senemos_parse_check: ; @:' senemos_parse_check >/dev/null 2>&1; then
            rm -f "$record"
            echo 'Discarded an incomplete dependency record from an interrupted build'
        fi
    done
fi
if test ! -e %{uke_boot_userspace}; then
    bash boot-recipe/src/boot/make-initramfs-base.sh %{uke_boot_userspace} '%{krel}'
fi
test "$(cat %{uke_boot_userspace}/kernel-release)" = '%{krel}'
(cd %{uke_boot_userspace}; sha256sum -c base-files.sha256)
(cd boot-recipe/src/boot; sha256sum -c %{uke_boot_userspace}/recipe-files.sha256)
find %{uke_boot_userspace}/base -type l -printf '%%P\t%%l\n' | LC_ALL=C sort > %{_topdir}/base-links.tsv
cmp %{_topdir}/base-links.tsv %{uke_boot_userspace}/base-links.tsv
bash boot-recipe/src/boot/build-payload.sh "$PWD" %{_uke_out} %{uke_boot_userspace}/base '%{krel}' '%{_uke_jobs}'
for item in CONFIG_PINCTRL_CLIFFS=y CONFIG_SM_GCC_CLIFFS=y \
    CONFIG_QCOM_RPMH_UKE=y CONFIG_INTERCONNECT_QCOM_CLIFFS_USB=y \
    CONFIG_EFI=y CONFIG_EFI_STUB=y CONFIG_MODULES=y; do
    grep -Fx "$item" %{_uke_out}/.config || exit 1
done
install -m644 senemos-applied-patches.txt %{_uke_out}/senemos-applied-patches.txt
test "$(make -s O=%{_uke_out} LOCALVERSION=-senemos.%{senemos_build_release} kernelrelease)" = '%{krel}'
%else
# A lifecycle-test release repackages the already verified build, without
# short-circuit RPM dependencies or a second kernel compilation.
test -s %{_uke_out}/arch/arm64/boot/Image
test -s %{_uke_out}/Module.symvers
test -s %{_uke_out}/linux.img
grep -Fx 'kernel_release=%{krel}' %{_uke_out}/boot-manifest
cmp senemos-applied-patches.txt %{_uke_out}/senemos-applied-patches.txt
%endif

%check
bash boot-recipe/tests/boot-image-contract.sh %{_uke_out}/boot-image
bash boot-recipe/tests/target-privacy-contract.sh
for option in SUSPEND PM_DEBUG PM_SLEEP_DEBUG; do
    grep -Fx "CONFIG_${option}=y" %{_uke_out}/.config
done
CXX=clang++ bash %{SOURCE4} "$PWD"
CC=clang bash %{SOURCE5} "$PWD"
CC=clang bash %{SOURCE6} "$PWD"
CC=clang bash %{SOURCE7} "$PWD"
bash %{SOURCE8} "$PWD/drivers/gpu/drm/sysfb/simpledrm.c" "$PWD/include/linux/backlight.h"
bash %{SOURCE9} "$PWD"
bash %{SOURCE10} "$PWD/drivers/interconnect/qcom/qnoc-cliffs-usb.c"
CC=clang bash %{SOURCE11} "$PWD/drivers/gpu/drm/msm/adreno/adreno_device.c"
CXX=clang++ bash %{SOURCE12} "$PWD/drivers/cpufreq/qcom-cpufreq-hw.c"
CXX=clang++ bash %{SOURCE13} "$PWD/drivers/gpu/drm/sysfb/drm_sysfb_modeset.c"
CC=clang bash %{SOURCE14} "$PWD"

%install
mkdir -p %{buildroot}%{_prefix}/lib/modules
cp -a %{_uke_out}/boot-modules/lib/modules/%{krel} %{buildroot}%{_prefix}/lib/modules/
module_dir=%{buildroot}%{_prefix}/lib/modules/%{krel}
install -m644 %{_uke_out}/arch/arm64/boot/Image "$module_dir/vmlinuz"
install -m644 %{_uke_out}/.config "$module_dir/config"
install -m644 %{_uke_out}/System.map "$module_dir/System.map"
mkdir -p "$module_dir/dtb/qcom"
install -m644 %{_uke_out}/arch/arm64/boot/dts/qcom/sm7675-xiaomi-uke.dtb "$module_dir/dtb/qcom/"
depmod -b %{buildroot} -m /usr/lib/modules -a %{krel}
mkdir -p %{buildroot}%{_datadir}/senemos/uke/%{krel}
install -m644 senemos-adaptation/source-lock.json \
    %{buildroot}%{_datadir}/senemos/uke/%{krel}/source-lock.json
install -m644 %{_uke_out}/senemos-applied-patches.txt \
    %{buildroot}%{_datadir}/senemos/uke/%{krel}/applied-patches.txt
bundle=%{buildroot}%{_prefix}/lib/senemos/kernel-updates/%{krel}
mkdir -p "$bundle"
install -m644 %{_uke_out}/linux.img "$bundle/linux.img"
install -m644 %{_uke_out}/modules.sha256 "$bundle/modules.sha256"
install -m644 %{_uke_out}/boot-manifest "$bundle/manifest"
install -m644 %{SOURCE16} "$bundle/source-lock.json"
install -m644 %{uke_boot_userspace}/build-rpms.tsv "$bundle/build-rpms.tsv"
mkdir -p %{buildroot}%{_datadir}/licenses/%{name}-boot-%{version}-%{release}
cp -a %{uke_boot_userspace}/licenses/. %{buildroot}%{_datadir}/licenses/%{name}-boot-%{version}-%{release}/
cp -a boot-recipe/src/boot/licenses/. %{buildroot}%{_datadir}/licenses/%{name}-boot-%{version}-%{release}/

%posttrans boot -p /bin/sh
if grep -Fxq 'automatic=1' /etc/senemos/kernel-update.conf 2>/dev/null; then
    /usr/bin/uke-kernel-update apply /usr/lib/senemos/kernel-updates/%{krel} || exit 1
fi

%post modules -p /bin/sh
if command -v depmod >/dev/null 2>&1; then depmod -a %{krel}; fi

%postun modules -p /bin/sh
# Reindex only when another release of this module package remains installed.
# On the last removal, regenerating indexes would leave unowned kernel files.
if test "$1" -gt 0 && command -v depmod >/dev/null 2>&1 && test -d /usr/lib/modules/%{krel}; then
    depmod -a %{krel}
fi

%files
%doc senemos-adaptation/README.md
%license COPYING

%files core
%dir /usr/lib/modules/%{krel}
/usr/lib/modules/%{krel}/vmlinuz
/usr/lib/modules/%{krel}/config
/usr/lib/modules/%{krel}/System.map
/usr/lib/modules/%{krel}/modules.builtin
/usr/lib/modules/%{krel}/modules.builtin.modinfo
%verify(not mtime) /usr/lib/modules/%{krel}/modules.builtin*.bin
/usr/lib/modules/%{krel}/modules.order
/usr/share/senemos/uke/%{krel}/source-lock.json
/usr/share/senemos/uke/%{krel}/applied-patches.txt

%files modules
/usr/lib/modules/%{krel}/kernel/
%verify(not mtime) /usr/lib/modules/%{krel}/modules.alias*
%verify(not mtime) /usr/lib/modules/%{krel}/modules.dep*
%verify(not mtime) /usr/lib/modules/%{krel}/modules.devname
%verify(not mtime) /usr/lib/modules/%{krel}/modules.softdep
%verify(not mtime) /usr/lib/modules/%{krel}/modules.symbols*
%verify(not mtime) /usr/lib/modules/%{krel}/modules.weakdep

%files dtbs
/usr/lib/modules/%{krel}/dtb/

%files boot
/usr/lib/senemos/kernel-updates/%{krel}/
%license /usr/share/licenses/%{name}-boot-%{version}-%{release}/

%changelog
* Thu Oct 15 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.40
- Build a source-only stock-ABL boot payload with its matching versioned modules.
- Invoke the locally configured native boot updater after the RPM transaction.
* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.39
- Revalidate a USB2 source that has not finished charger-service startup.
- Record bounded budget results while retaining refusals for unsuitable sources.
* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.38
- Advertise the enumerated USB2 sink budget on the Uke serial gadget.
- Retain source limits and firmware charging controls; net charging needs measurement.
* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.37
- Keep an active panel at a visible one-percent brightness minimum.
- Preserve true backlight blanking, suspend and paired transaction rollback.

* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.36
- Bound firmware-framebuffer copies after fractional damage clipping.
- Retain source panning and test the actual update loop against the observed overrun.

* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.35
- Package the matched kernel and the initramfs that reached the Fedora root.
- Retain the explicit CDC development console through the root transition.

* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.34
- Retain the display metadata, uinput and GPU removal fixes on the working base.
- Preserve SM7675 CPU core-count operating points and reviewed GPU frequencies.

* Wed Oct 14 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.10-1.33
- Preserve SM7675 EPSS core-count operating points, including the Prime domain.
- Test the actual LUT parser while retaining other platforms' turbo behavior.

* Tue Oct 13 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.10-1.32
- Carry the Uke adaptation and experimental Adreno 732 support to Linux 7.2.10.
- Derive the reproducible build timestamp from the signed-source profile.

* Tue Oct 13 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.29
- Order charger prerequisites and retry bounded early SDP requests
- Correct exact-Uke current direction and charge-counter units
- Link the USB consumer to its power supplier before provider teardown

* Tue Oct 13 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.28
- Expose standard suspend diagnostics for staged s2idle and wake-source qualification
- Retain automatic sleep containment until device suspend and resume pass

* Mon Oct 12 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.27
- Link Uke firmware DRM blanking to its paired backlight without changing panel power.

* Mon Oct 12 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.26
- Connect the bounded USB2 SDP budget, reject unsolicited replies and start the exact Uke charger DSP

* Mon Oct 12 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.25
- Admit a battery-only upstream Uke GLINK endpoint; retain legacy USB-role containment

* Mon Oct 12 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.24
- Translate exact Uke OEM battery telemetry IDs and signed temperature; retain manual ADSP and charging qualification gates

* Mon Oct 12 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.23
- Propagate SLIMbus DMA, power and QMI startup errors before registration.
- Run the production-function startup fault controls in native RPM checks.

* Mon Oct 12 2026 Mürşit Can Cihan <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.22
- Add the exact OEM Uke two-channel CPUCP mailbox with fail-closed resources.
- Test real resource and I/O paths without changing modern mailbox operations.
* Mon Oct 12 2026 Mürşit Can Cihan <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.21
- Add only the five protection domains measured in Uke's pinned OEM registry.
- Reuse matching mainline services without donor domains or DMA permission changes.
* Mon Oct 12 2026 Mürşit Can Cihan <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.20
- Use the actual mainline GPR domain header and constant in the Uke fallback.
- Require that production header in the native regression instead of a mock value.
* Mon Oct 12 2026 Mürşit Can Cihan <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.19
- Read the exact OEM Uke GPR ADSP domain while preserving mainline properties.
- Test accepted and refused domain paths from the actual prepared APR code.
* Mon Oct 12 2026 Mürşit Can Cihan <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.18
- Register the exact Cliffs LPASS interconnect route required by Uke ADSP.
- Preserve OEM LP0 membership and existing QUP, USB and UFS paths.
* Sun Oct 11 2026 Mürşit Can Cihan <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.17
- Use built-in simpledrm and DRM fbdev for the early firmware console.
- Respect upstream exclusion of simpledrm and the legacy simplefb driver.
* Sun Oct 11 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.8
- Preserve OEM Uke WLAN forward rail order and reverse shutdown.
- Keep partial enable ownership after failed cleanup for balanced retry.
- Mark Cliffs GPIO functions for strict pinmux and GPIO coexistence.

* Sun Oct 11 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.7
- Require exact Uke WCN6750 RF supplies and unwind failed firmware starts.
- Admit only the OEM WLAN SMMU stream/mask while retaining translated DMA.

* Sun Oct 11 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.6
- Add exact Cliffs WPSS PAS and required CX/MX ARC proxy regulators.
- Keep firmware startup manual and require AOP QMP; WLAN admission remains gated.
* Tue Oct 06 2026 Senemos Maintainers <75160848+MCC45TR@users.noreply.github.com> - 7.2.9-1.4
- Add attributed SM7675 UFS PHY tuning and EFI framebuffer console configuration.
- Keep board UFS and physical boot acceptance gated separately.
* Sun Oct 04 2026 Senemos Maintainers <MCC45TR@users.noreply.github.com> - 7.2.9-1
- Build the Uke platform adaptations with Fedora Rawhide packaging.
