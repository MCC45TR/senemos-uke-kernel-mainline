# Senemos Uke Mainline Kernel

Linux kernel adaptations, device trees and Fedora AArch64 packages for Xiaomi Pad 7 and POCO Pad X1 (`uke`, Qualcomm SM7675).

**Updated 26 October 2026. Current development series: Linux 7.3.**

[Platform support](https://github.com/MCC45TR/uke-linux#hardware-support) · [Test COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Build guide](docs/BUILDING.md) · [Native profile](packaging/native/README.md)

## Device status

The latest recorded normal POCO Pad X1 boot is `7.3.0-15`, installed from signed [COPR build 11207395](https://copr.fedorainfracloud.org/coprs/build/11207395/). The matched package inventory, modules, boot-image readback and existing boot-health acceptance passed on 26 October. Android boot A was preserved by that reviewed update. Touch, login, SSH and NetworkManager services were active after startup.

Current Fedora testing uses the stock Android bootloader. Project Aloha is a separate firmware project, and the observed handoff remains EL1. A KVM package build does not establish access to EL2 or an operational virtual machine.

| Area | Recorded result | Remaining work |
|---|---|---|
| Internal display | Native O82 DPU/DSI/DSC output and fixed refresh modes in recorded KDE sessions | Repeat mode/lifecycle checks on each new kernel; variable-refresh and touch regressions remain separate. |
| Touch and controls | Normal finger input and physical buttons worked; native touch services start | Continuous contact, ten-contact/VRR faults and latest gesture-entry timeouts. |
| Networking and sensors | Wi-Fi, SSH and earlier physical rotation/light/proximity results | Broader current-kernel lifecycle and DSP restart tests. |
| Juo external output | HDMI operation on Linux 7.3 confirmed on 26 October; earlier 1440p/75 Hz result recorded | Current mode/precision, reconnection, DDC/CI and compressed/HDR output require separate checks. |
| External DSC/FEC | Transport, RC/PPS, receiver-event and native package checks pass | Experimental policy stays disabled by default; actual receiver enable and visible compressed output are unqualified. |
| Iris video | Selected source/object and runtime initialization work exists | Real decoded/encoded frames, Main10, DMA-BUF/fences and sustained playback. |
| Charging | Telemetry and guarded software interfaces | Electrical limits, cutoff/restart, negotiated protocols, protection and endurance. |
| Torch/RGB | Guarded driver and native control source | Physical output, channel mapping and measured electrical/thermal behavior. |
| Sleep/wake | Earlier limited RTC-wake result | Repetition, display/touch, power/input wake and sleep energy. |
| Internal audio and cameras | No accepted playback/capture result | Protected audio routing and actual image/audio capture. |

Earlier Linux 7.2 results remain dated evidence. The full [hardware table](https://github.com/MCC45TR/uke-linux#hardware-support) states each function's scope; it does not qualify the current kernel or another memory/storage variant by association.

## Source and package organization

`main` tracks the reviewed normal source selection. Separate branches retain KVM, earlier 7.2 experiments and uninstalled candidates. Each source manifest pins the kernel archive, patches and configuration; source-only and compiled results remain distinct.

Fedora packages keep the kernel, modules, device trees and boot/root selections matched. The singleboot selection shares the reviewed native kernel rather than creating an independently qualified hardware port. Use the complete coherent package tuple and preserve one working rollback.

New firmware, display, power, USB or input changes require exact Uke evidence and attributable upstream/shared-IP comparison. Existing Linux C/assembly conventions and original licenses are retained. No board offsets, security binaries or calibration are transferred from Nabu or another tablet.

## Build

Use the checked-in workspace entry point:

```sh
git clone --recurse-submodules https://github.com/MCC45TR/uke-linux.git
cd uke-linux
./ukelinux.sh --build kernel
```

For direct source work, inspect `./senemos.sh --help` and [BUILDING.md](docs/BUILDING.md). The native source/package profile is documented in [packaging/native](packaging/native/README.md). Package names, source revisions and generated output must be checked before installation.

Host/source tests, cross-compilation, native COPR builds, signatures, installation and actual tablet behavior are separate checks. A successful build does not establish display, charging, audio, video or suspend acceptance.

## Updates and recovery

Use the [public installation guide](https://github.com/MCC45TR/uke-fedora-builder/blob/main/docs/PUBLIC-BUILD.md) and the matching package update path. Preserve stock early firmware, the accepted boot image and matching modules. Do not guess an active slot or bypass a failed identity/readback check.

Source publication does not start a device update. No flash, reboot or physical test is implied by this documentation update.

## Development checkpoints

[The 26 October source checkpoint](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/publish/source-snapshot-20261026) preserves pending 7.2.12 source/configuration work separately from normal 7.3 delivery. Other feature branches retain their own test and delivery limits.

Report the exact source commit, kernel release, package tuple, device variant, date and redacted reproduction evidence. Keep raw logs, unit identifiers, keys and calibration private.
