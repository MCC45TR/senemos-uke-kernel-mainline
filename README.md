# Senemos Uke Mainline Kernel

Linux kernel, device trees and Fedora packages for Xiaomi Pad 7 and POCO Pad X1
(`uke`, Qualcomm SM7675).

**Development target:** Linux 7.2.9 · AArch64 · Fedora Rawhide

[Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support) · [Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Source profile](manifests/linux-7.2.9.json)

## Status — 13 October 2026

Matched RAM boots reach the tablet console, internal Fedora root, the KDE
desktop and Wi-Fi SSH. Battery readings and manual backlight control are
available. Touch, Bluetooth, audio and USB host mode remain
incomplete. Detailed results are in the [project hardware table](https://github.com/MCC45TR/uke-linux#hardware-support).

The experimental Adreno 732 port passes native shader and pixel-readback tests
at 255 MHz. The original Fedora KWin also reports hardware OpenGL ES rendering.
Mesa currently labels this exact chip `FD735`; the kernel reports `0x43030b00`.
Xwayland acceleration, Vulkan, higher frequencies and suspend remain incomplete.
These results use a RAM candidate with matched local GPU modules and firmware;
they do not qualify a signed COPR package or normal slot-B startup.

Tablet testing currently uses package revision **1.27**. The **1.29** charger and
battery corrections are on `main`. The **1.30** brightness candidate has passed
native COPR, signed package and module checks, but has not been tested on the
tablet. Suspend remains disabled. Normal slot-B startup and repeated cold boots
still need work; successful compilation does not establish hardware support.

GPU package revision **1.31** is separate from the **1.30** brightness candidate.
GPU builds stay in the `custom:gpu` COPR directory until package and boot tests
complete. The stock-ABL overlay preserves firmware scanout and uses only the
lowest OEM GPU operating point. The independent Uke DTS is a separate boot path.

The current firmware handoff is **EL1**. EL2/KVM is a separate experimental
branch. Uke UEFI integration is not ready. Pad 7 Pro (`muyu`) and Pad 5 (`nabu`)
are different targets; their firmware and device settings are not reused.

## Packages

| Package | Contents |
|---|---|
| `senemos-uke-linux-kernel-mainline` | Matching core, modules and DTB package set |
| `senemos-uke-linux-kernel-mainline-core` | ARM64 Image, config, System.map and source identity |
| `senemos-uke-linux-kernel-mainline-modules` | Modules for the same kernel and configuration |
| `senemos-uke-linux-kernel-mainline-dtbs` | Independent Uke device tree |

For Fedora Rawhide AArch64 development systems:

```sh
sudo dnf copr enable mcc45tr/uke-linux-test
sudo dnf install senemos-uke-linux-kernel-mainline
sudo dnf upgrade 'senemos-uke-linux-kernel-mainline*'
```

COPR signs the RPMs. Kernel files are installed under
`/usr/lib/modules/7.2.9-senemos-uke/`. DNF updates files and module dependencies;
it does not flash `boot_b`, create a UEFI entry or select a boot slot.

Revisions of Linux 7.2.9 share the same module directory. A tablet update needs
a matching Image, initramfs, device tree and module set. Preserve the working
boot image and rollback before replacing that set. Development headers are not
published yet.

## Build from source

```sh
git clone https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
cd senemos-uke-kernel-mainline
./senemos.sh --build 7.2.9 --distro=fedora --test
./senemos.sh --build latest --distro=fedora
```

`senemos.sh` verifies signed upstream source, applies the reviewed Uke patches
and configuration, then builds Image, DTBs, modules, RPMs and an SRPM in the
pinned container. Source and build caches are retained. `latest` requires a
reviewed Uke version profile and stops if one is missing. Other distributions
are planned targets.

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
