# Senemos Uke Mainline Kernel

Linux kernel, device trees and Fedora packages for Xiaomi Pad 7 and POCO Pad X1
(`uke`, Qualcomm SM7675).

**Development target:** Linux 7.3 · AArch64 · Fedora Rawhide

[Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support) · [Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Linux 7.3 source](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/codex/display-isolation73-20261025)

The earlier 18 October source targets Linux 7.2.11 with USB,
battery and VRR adaptations. Its native charger-boot handoff selects a separately
packaged minimal charging interface only from an explicit bootloader signal.
It does not qualify charge cutoff, bypass or physical offline charging. Tablet
results below retain their exact older kernel identities until separately tested.

## Status — 26 October 2026

POCO Pad X1, 8 GB / 512 GB, Fedora Rawhide AArch64 and original KDE normally
boots signed Linux `7.3.0-15`, [COPR 11207395](https://copr.fedorainfracloud.org/coprs/build/11207395/).
Matching modules, boot-image readback and the existing boot-health gate pass.
The normal source is on [the display-isolation branch](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/codex/display-isolation73-20261025).
Separate experimental branches are not automatically qualified by this boot.

HDMI works on Linux 7.3, confirmed on 26 October. Earlier Linux 7.2.12-31 tests
establish Juo monitor sound and Gigabit Ethernet connectivity. Internal display,
normal touch, fixed refresh modes, Wi-Fi, selected Bluetooth and sensors have
dated working results. The bounded RGB color test passes on Linux 7.3.0-5.
On kernel 15, native Iris produces 30 exact-reference constrained-baseline H.264
frames at 320x240 with locally provisioned VPU firmware; High produces a corrupt
frame and firmware errors. Browser video, other codecs, encoder output and
sustained media operation remain unqualified.

VRR remains disabled after input/display faults. External DSC/FEC is experimental
and disabled by default. HDR, DDC/CI, four-lane/MST operation, suspend, charging
protection, internal audio and cameras retain separate open gates. Working HDMI
does not establish any of those functions. The observed firmware handoff is EL1;
a KVM package does not establish EL2 or guest execution.

The [full hardware table](https://github.com/MCC45TR/uke-linux#hardware-support)
distinguishes older successful observations from current-kernel tests and exact
exported-image acceptance. The [published source checkpoint](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/publish/source-snapshot-20261026)
preserves pending 7.2.12 source separately from the normal 7.3 delivery.

## Earlier native display and sensor results

The following records describe the earlier 14–18 October baseline. The later
VRR/input regression supersedes its unrestricted VRR acceptance. Current
function-level status and exact-kernel limits are listed above and in the
main project's hardware table.

The signed COPR `7.2.10-10` development bundle installs through DNF and reaches
original Fedora KDE through native O82 DPU/DSI after a normal KDE reboot.
Original Fedora Plasma Login Manager now starts the Wayland session.
Release 10 binds CPUCP and exchanges the SCMI v2.0 base protocol with the
Qualcomm firmware; vendor memory-latency control and suspend remain unqualified.
The release-13 candidate disables only the exact empty secondary SPMI controller
and zero-length OEM demura placeholders, and follows the OEM EVO/OLE reset-time
PLL latch rule with checked register accesses. Aligned FDT and actual PLL
fixtures pass with AArch64 Clang; populated nodes, reservations and active PLL
checks are retained. Tablet validation of these boot changes is pending.
The previous .4056 normal-boot user checks confirm
automatic four-pose rotation and dual-light automatic brightness. Bluetooth
mouse input works. The earlier seven-rate display trial covers
30/48/50/60/90/120/144 Hz with nine transitions retaining panel and touch state.
Long-run, suspend and VRR qualification remain open. The verified .4054 image
and matched modules remain the rollback.

The source producer now builds Image, matching modules, DTBs and an Android
boot container with a source-generated initramfs. Integer releases use
`7.2.10-1`, `-2`, `-3`, and restart at `7.2.11-1` after a new upstream pin.
[COPR 11165188](https://copr.fedorainfracloud.org/coprs/build/11165188) builds
`7.2.10-8`, including 49 baseline patches, standard PMIC IIO/hwmon/thermal
consumers and native CPU emergency cooling maps. Signatures, matching Image,
modules and boot-container checks pass. The tablet exposes all 27 configured
PMIC IIO channels, two Hall input devices and 51 readable thermal zones.
Original KDE's sensor backend reads all 27 PMIC measurements. The battery
thermistor and two current feedback channels return live values; charger
temperature reads 31.29–31.41 °C with USB power. Without USB power its input
is near zero and the OEM formula clamps the result to 0 °C. All ten captured
raw/result pairs match an independent integer calculation; absolute calibration
remains unqualified.
Front close/open and rear fold/unfold produce standard switch events;
logind tracks the lid. Cover-triggered display blanking remains unqualified.
Software-emulated thermal events in the earlier release-4 test lower three
CPU policy limits and the GPU cap; all emulation values are cleared afterward.
Original KDE System Monitor's backend returns live PMIC values and battery
voltage, signed current and derived power with standard units.
[COPR 11165033](https://copr.fedorainfracloud.org/coprs/build/11165033) builds
release 5 with the SMP2P edge-history correction. Signed delivery and bounded
tablet traces confirm stable ready/handover counters while sleep-state updates
continue. Full shutdown still has an upstream clipboard deadlock; two SPI/GPI
timeouts leave long-idle touchscreen reliability open.

The OEM non-linear backlight mapping is retained. Only the exact OEM root/sensor
FastRPC contexts are admitted. All four previously excluded ADC conversions
are ported from the exact OEM source. Complete OEM skin/BCL policy remains
incomplete. Sustained CPU/GPU thermal behavior is
unqualified. See the [source profile](packaging/native/README.md) and
[integration record](packaging/INTEGRATION-20261017.md) for delivery boundaries.
The combined source contains the default-off [AVR experiment](docs/O82-VRR-EXPERIMENT.md).
The standard atomic VRR property is attached. Bounded release-9 tests activate
both interfaces with no active underruns across the seven base modes. Cold
144 Hz activation with the wide experiment can prevent touch command completion;
disable-time underruns and physical scan-cadence qualification remain open.
No qualified VRR range is advertised.

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
| `senemos-uke-linux-kernel-mainline-dtbs` | Independent Uke device tree and native display overlay |
| `senemos-uke-linux-kernel-mainline-boot` | Matched Android boot container, module inventory and boot provenance |

For Fedora Rawhide AArch64 development systems:

```sh
sudo dnf copr enable mcc45tr/uke-linux-test
sudo dnf --setopt=installonly_limit=0 install senemos-uke-linux-kernel-mainline
sudo dnf --setopt=installonly_limit=0 upgrade 'senemos-uke-linux-kernel-mainline*'
```

COPR signs the RPMs. Integer releases have separate module paths such as
`/usr/lib/modules/7.2.10-4/`. Keep the previous kernel and complete boot image.
The boot package calls the native updater only when automatic updates are
explicitly enabled locally. It validates the matched inventory, retains the
previous full image, writes only slot B and verifies readback. It does not
select another slot or change partitions. Installation on an unconfigured
system does not enable boot writes. See the updater's validation requirements
before enabling it. Development headers are not published yet.

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
the embedded specification. The source package supplies Image, matched modules, DTBs and a boot container
with an embedded, source-generated initramfs. No OEM firmware or per-device
calibration is a package source input.

The 23 October 2026 release-20 source candidate builds only the Uke DTB and
native display overlay. Its configuration removes unrelated fixed-board
drivers and reduces the early module list while preserving generic USB
accessories, root filesystems, firewall, virtualization and diagnostics.
The build checks the retained suppliers and early dependency closure.
Source/build validation does not establish tablet boot or a measured speedup.

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
## Release channels

25 October 2026: the normal mainline package and its matched singleboot child
follow Linux 7.3.x. The scheduled selector uses the newest admitted 7.3 release,
including upstream's `7.3` spelling, and retains signed-source verification.
An older source queue requires a reviewed port before automatic updates.
The common package builds its own singleboot child in the same COPR transaction;
the separate historical metadata branch is not advanced for this channel.

The unstable channel is reserved for Linux 7.4-rcN. Its source recipe refuses
the retained 7.3 tree before installing build dependencies. A new RC still needs
its signed archive, reviewed adaptation and package checks; the channel change
does not qualify an unreleased kernel or establish tablet support.
