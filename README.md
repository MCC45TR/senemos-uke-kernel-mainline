# Senemos Uke mainline kernel

Mainline Linux development for POCO Pad X1 and Xiaomi Pad 7 (`uke`, SM7675). The
current kernel/RPM product is **`senemos-uke-linux-kernel-mainline`**. Linux
**7.2.8** remains the historical generic baseline; the reviewed Uke adaptation
targets **7.2.9**. Hardware results remain scoped to the tested model and SKU.

[Uke Linux](https://github.com/MCC45TR/uke-linux) · [Kernel architecture](docs/ARCHITECTURE.md) · [Hardware status](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md) · [Releases](https://github.com/MCC45TR/senemos-uke-kernel-mainline/releases)

## Development scope

The first platform path covers CPU and firmware interfaces, clocks and power, pin control, USB, storage and an early console. A standalone mainline device tree follows the stock-DT transition profile. Display, touch, GPU, wireless, audio, sensors, charging, suspend and camera work are tracked independently in the [device matrix](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md).

The Uke Linux 6.12 community port and OEM/Android sources are evidence for a forward port, not a substitute for mainline validation. Kernel changes are split by subsystem with source attribution, build checks and focused error-path tests. Android 6.1 vendor modules are not reused as Linux 7.2 modules.

## Downloads

Linux 7.2.9 Uke development RPMs and their SRPM are now in the
[uke-linux-test COPR channel](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/).
First native job [11074297](https://copr.fedorainfracloud.org/coprs/build/11074297)
succeeded. Local signed-source compilation produced the Image, independent Uke
DTB and 1,146 matching AArch64 modules; payload, ABI, offline SRPM preparation
and actual package install/upgrade/removal checks passed. Same-version packaging
corrections use an increasing RPM release. The
[builder records](https://github.com/MCC45TR/uke-fedora-builder/tree/main/reports)
separate local, remote, host-bootstrap and emulated userspace results.
Physical boot and peripheral compatibility remain untested. See
[automatic source builds](docs/AUTOMATION.md) and the
[package hub](https://github.com/MCC45TR/uke-linux/blob/main/docs/PACKAGE-HUB.md).

The pinned upstream `arm64 defconfig` [compiled to `Image` and DTBs](reports/BASELINE-BUILDABILITY.md).
That historical generic Linux 7.2.8 baseline contains no Uke DTB and has no boot
validation.

The independent 7.2.9 Uke DTS and seven subsystem patches are documented in
[the attributed patch series](patches/7.2.9/README.md), with exact source,
signature, patch and config identities in [the version profile](manifests/linux-7.2.9.json).
The workspace's `senemeos.sh` builds them together with matching ARM64 modules
and Fedora Rawhide packages. The DTS is a compile-stage candidate with
unreviewed peripherals disabled; a future UEFI loader must provide exact-profile
RAM and dynamic reservations. This does not establish tablet boot or peripheral
support. Existing 7.2.8 source and outputs are retained.

The active source checkout is created from a pinned upstream revision under `src/upstream/`; large unchanged reference repositories live locally in `referances/`. [The workspace plan](https://github.com/MCC45TR/uke-linux/blob/main/PLAN.md) defines the ordered bring-up. Kernel code follows Linux C/assembly conventions; native companion tools use C++. See [AGENTS.md](AGENTS.md) and the original source licenses before contributing.
