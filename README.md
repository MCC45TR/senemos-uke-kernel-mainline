# Senemos Uke Mainline Kernel

Linux kernel, device trees and Fedora packages for Xiaomi Pad 7 and POCO Pad X1
(`uke`, Qualcomm SM7675).

**Development target:** Linux 7.2.10 · AArch64 · Fedora Rawhide

[Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support) · [Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Source profile](manifests/linux-7.2.10.json)

## Status — 18 October 2026

Signed COPR 11167990 installs `7.2.10-27` through DNF on POCO Pad X1, Fedora
Rawhide AArch64 and original KDE. The guarded updater verifies boot B by
readback and preserves Android boot A unchanged. A normal reboot reaches the
desktop through native O82 DPU/DSI. Touch is active with zero service restarts;
the saved VRR policy and balanced power profile persist. The previous DP
connector-state Oops and UCSI initialization timeout are absent. Brief
white-flash behavior and long-duration stability remain unqualified.

With the powered Juo dock attached, USB 2 and 5-Gbit/s USB 3 hub trees, a
YICHIP HID receiver and an RTL8153 Ethernet adapter enumerate. Evdev records
mouse motion and the user confirms pointer operation. The standard Type-C
interface reports host data role, sink power role and USB-PD mode while the
tablet charges. This does not establish a negotiated voltage, wattage or all
charging protocols. Ethernet has no cable/carrier test yet. HDMI remains
disconnected. A PMIC probe warning and optional front-color startup failure
remain open; this is not a clean-log or complete dock acceptance result.

The current internal path uses RGB101010 and 10-bpc DSC; KDE scans out AR30.
Selectable internal 8/10/12-bpc link profiles are not implemented. Advertised
12-bit panel capability does not identify a qualified 12-bpc transport or FRC
path. External DP exposes a 6..10 max-bpc property. No unsupported color-depth
or RGB-range choice is advertised for DSI.

Release 27 corrects the UCSI type-2 notification path. On that kernel, a
controlled HDMI reconnect also produces a type-2, 32-byte DP notification on
the separate alternate-mode channel. Its callback still applies a global
type-1-only filter. The release-28 source candidate dispatches that channel's
notification types separately from strict write acknowledgements. It retains
owner, payload-parser, bounded queue and lifecycle guards. It also enables
standard XZ/Zstandard firmware loading: Fedora supplies the requested Realtek
firmware as an XZ file, while release 27 cannot decode compressed firmware.
Source checks, native packaging and physical HDMI/Ethernet results remain
separate validation stages.

Signed COPR 11168191 subsequently provides release 28. Exact source/payload,
signature, module and initramfs checks pass. DNF installs the matched bundle;
boot B readback matches and Android A is unchanged. A normal reboot returns to
SSH and the original KDE session. Touch service readiness and zero restarts
are verified; physical display/touch confirmation is pending. The first KDE
policy is Automatic; the previous Always preference is restored through
KScreen and persisted. With 144 Hz selected, DPU measurement reports about
30 Hz at idle with VRR enabled; this is not optical panel metrology.

The earlier Realtek missing-firmware error is absent after the compressed-loader
change, and the NIC binds. Ethernet traffic is untested. DP remains disconnected;
an initial alternate-mode mux error is recorded with the unpowered dock. The
user reports this Juo dock requires PD power for HDMI even on a laptop, so an
unpowered display trial is inconclusive. Powered HDMI testing is deferred while
battery termination and system-power behavior remain unqualified. No battery
bypass control or electrical-protection acceptance is claimed.

CDC defaults off in the matched full-profile boot/root pair; explicit ACM
opt-in is provided by the separate native management package. Charging services
remain disabled and the shipped qualification profile is unqualified. No raw
PD/voltage, gauge or factory command is supplied. See the
[Type-C profile](docs/USB-TYPEC-FULL-PROFILE-20261018.md) and
[charging protocol limits](docs/CHARGING-PROTOCOLS-20261018.md).

The user accepts the existing VRR/touch baseline on 18 October 2026. This does
not establish a new instrumented 30–144 Hz panel-cadence measurement or acceptance
of the combined candidates. Seven fixed modes remain distinct from variable
refresh. Suspend is unqualified. The accepted previous boot image and matching
modules remain available for recovery.

## Earlier native display and sensor results

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
