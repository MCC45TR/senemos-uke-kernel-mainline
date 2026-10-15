# Senemos Uke Mainline Kernel

Linux kernel, device trees and Fedora packages for Xiaomi Pad 7 and POCO Pad X1
(`uke`, Qualcomm SM7675).

**Development target:** Linux 7.2.9 · AArch64 · Fedora Rawhide

[Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support) · [Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Source profile](manifests/linux-7.2.9.json)

## Status — 15 October 2026

Linux **7.2.9, revision 1.39** starts from slot B on POCO Pad X1 and reaches the
internal Fedora Rawhide root, KDE desktop and Wi-Fi SSH. KWin uses Adreno 732
hardware rendering; display scanout still uses the firmware framebuffer through
simpledrm. Native DPU/DSI, refresh-rate switching and display stability remain
incomplete. Detailed results are in the
[project hardware table](https://github.com/MCC45TR/uke-linux#hardware-support).

Finger input, ten simultaneous contacts, and power and volume buttons worked in
the 14 October tablet test. Revision 1.39 reaches touch input on its first startup
attempt. Manual backlight control and display blanking work, with a minimum
visible level while the display is on. The paired backlight uses the OEM mapping;
smooth adjustment across the full range remains unqualified.
Battery readings and USB charging status are available; the tested computer USB
connection admits a 500 mA budget. Sustained net charging under desktop load is
not established. Bluetooth, audio, USB host mode and suspend remain incomplete.

The normal source profile contains 44 adaptation patches. Its revision 1.39
packages were built and signed locally for tablet testing; this does not qualify
a new COPR build. Linux 7.2.10 and native display sources remain separate
candidates and have not produced a working display. Repeated cold boots, display
lifecycle tests and sustained workloads remain open.

The current firmware handoff is **EL1**. EL2/KVM is a separate experimental
branch. Uke UEFI integration is not ready. Pad 7 Pro (`muyu`) and Pad 5 (`nabu`)
are different targets; their firmware and device settings are not reused.

## Packages

| Package | Contents |
|---|---|
| `senemos-uke-linux-kernel-mainline` | Matching core, modules, DTB and boot package set |
| `senemos-uke-linux-kernel-mainline-core` | ARM64 Image, config, System.map and source identity |
| `senemos-uke-linux-kernel-mainline-modules` | Modules for the same kernel and configuration |
| `senemos-uke-linux-kernel-mainline-dtbs` | Independent Uke device tree |
| `senemos-uke-linux-kernel-mainline-boot` | Stock-ABL boot B image, matched module inventory and build provenance |

For Fedora Rawhide AArch64 development systems:

```sh
sudo dnf copr enable mcc45tr/uke-linux-test
sudo dnf install senemos-uke-linux-kernel-mainline
sudo dnf upgrade 'senemos-uke-linux-kernel-mainline*'
```

Revision 1.40 introduces separate module directories such as
`/usr/lib/modules/7.2.9-senemos.1.40/`, preserving older kernel modules for
rollback. The boot package is built from source with its matching modules and
an AArch64 dracut initramfs; it contains no OEM firmware. With the native
`uke-kernel-update` tool installed and locally configured for automatic updates,
the RPM transaction validates the image and module tuple, saves the previous
boot bytes, writes `boot_b` and verifies readback. It does not reboot, change
the active slot or write Android A, ESP or the root partition.

The new source recipe and update path still require a successful matched
package installation and physical reboot test before being considered usable.
Development headers and the userdata root layout are not provided.

Revision 1.41 keeps PAS remoteproc loading on the real root, where the matched
OEM firmware is installed. The firmware-free initramfs retains storage and USB
drivers. Battery and DSP startup still require a separate tablet reboot check.

## Build from source

```sh
git clone https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
cd senemos-uke-kernel-mainline
./senemos.sh --build 7.2.9 --distro=fedora
./senemos.sh --build latest --distro=fedora
```

`senemos.sh` verifies signed upstream source, applies the reviewed Uke patches
and configuration, then builds Image, DTBs, modules, RPMs and an SRPM in the
pinned container. Source and build caches are retained. `latest` requires a
reviewed Uke version profile and stops if one is missing. Other distributions
are planned targets.

The source-only boot recipe currently builds natively on Fedora Rawhide
AArch64, including COPR. Cross-host compilation needs an AArch64 dracut base;
its automatic preparation is not integrated in `senemos.sh` yet, so other
architectures stop with an explicit error. `make srpm` remains available on
x86_64 for COPR submission. The `--test` lifecycle option requires a separately
compiled previous kernel release; it does not repackage identical objects as
an upgrade test.

```sh
make validate
make srpm
```

`make validate` checks patch/config hashes. `make srpm` verifies the source
archive and prepares the source package. See [BUILDING.md](docs/BUILDING.md)
for host requirements, offline builds and test scope.

After inspecting the stock firmware, the reviewed boot-DT helper is:

```sh
./senemos.sh --prepare-boot-dt RECEIPT KERNEL_SOURCE OUTPUT
```

The optional `--usb2-peripheral` profile is for device-mode diagnostics. It does
not provide USB host power and is not a replacement Android DTBO image.

## Updates and records

The [stable workflow](.github/workflows/stable-and-copr.yml) checks Kernel.org
daily. Reviewed source changes trigger COPR builds. Each new Linux version needs
its own pinned source, Uke patch/config profile and build/package checks before
publication. Device testing is recorded separately.

- [Automation](docs/AUTOMATION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [UFS bring-up](docs/UFS-BRINGUP.md)
- [USB host prerequisites](docs/ESP32-HOST-BRINGUP.md)
- [Build reports](reports/)
- [Private engineering records](https://github.com/MCC45TR/uke-linux-docs)

Contributions should state the device/firmware scope and checks performed.
Keep patches focused and preserve source attribution. Use [issues](https://github.com/MCC45TR/senemos-uke-kernel-mainline/issues)
for reproducible bugs and [SECURITY.md](SECURITY.md) for vulnerabilities.

Project tooling and documentation use [MIT](LICENSE). Linux code and derived
patches retain their original SPDX and GPL-compatible licenses.
