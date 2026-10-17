# Senemos Uke Mainline Kernel

Linux kernel, device trees and Fedora packages for Xiaomi Pad 7 and POCO Pad X1
(`uke`, Qualcomm SM7675).

**Development target:** Linux 7.2.10 · AArch64 · Fedora Rawhide

[Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support) · [Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Source profile](manifests/linux-7.2.10.json)

## Status — 17 October 2026

The mainline source package now includes the native O82 DPU/DSI profile and
the seven exact OEM display modes. The installed
`7.2.9-senemos.1.4054` development kernel displays KDE at 30/48/50/60/90/120/144 Hz.
Nine measured transitions on 17 October retained the panel reset count, touch
process and input device. Direct testing found no visible blanking or interrupted
single-finger/multitouch input. Repeated cold starts, suspend and long-run tests
remain open. Discrete switching does not provide Adaptive Sync.

[COPR build 11163806](https://copr.fedorainfracloud.org/coprs/build/11163806)
successfully built the consolidated mainline source as 7.2.9-1.4054.3.
Its raw Image is not the separately matched `.4054` tablet boot bundle.

The next candidate uses signed upstream Linux 7.2.10 with all 44 baseline
adaptations, the native54 display profile, exact SSC context banks and the Uke
Bluetooth UART/power graph. It preserves the accepted .4054 fallback. Source
preparation and host fixtures pass; candidate boot, sensor measurements,
Bluetooth input and repeated startup remain physical acceptance gates. VRR is
deferred; no continuous display range is advertised.

The OEM non-linear backlight mapping is retained. Timed fade remains historical.
Only the two exact OEM root/sensor context banks are admitted for SSC; other
FastRPC contexts remain disabled. See the [integration record](packaging/INTEGRATION-20261017.md)
for the source and package boundaries.

### Earlier firmware-framebuffer baseline — 15 October 2026

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

The earlier source profile contains 44 adaptation patches. Its revision 1.39
packages were built and signed locally for tablet testing; this does not qualify
a new COPR build. Linux 7.2.10 did not produce a working display in that test.
Repeated cold boots, display
lifecycle tests and sustained workloads remain open.

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

COPR signs the RPMs. Consolidated builds have a unique numeric module path,
such as `/usr/lib/modules/7.2.9-senemos.1.4054.3/`. DNF updates files and module dependencies;
it does not flash `boot_b`, create a UEFI entry or select a boot slot.

The older revision 1.39 used a shared module directory. New source packages
preserve previous kernels as install-only fallbacks. A tablet update needs
a matching Image, initramfs, device tree and module set. Preserve the working
boot image and rollback before replacing that set. Development headers are not
published yet.

## Build from source

```sh
git clone https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
cd senemos-uke-kernel-mainline
make validate
make srpm
```

`make validate` checks the reviewed version, patch/config hashes and mainline
package metadata. `make srpm` verifies the signed upstream archive and retains
the complete native profile, source identity and tests. The binary build uses
the embedded specification. The source package currently supplies a raw Image,
modules and DTBs, without an initramfs or flashable boot container.

`senemos.sh` retains the historical container build and stock-DT inspection
tools. Its host specification remains the earlier revision 1.39 profile; it
does not reproduce the consolidated native boot image. Its `latest` option
requires a reviewed source profile and stops if one is missing. See
[the source profile](packaging/native/README.md) and [BUILDING.md](docs/BUILDING.md)
for the explicit build and physical-test limits. Other distributions are planned.

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
