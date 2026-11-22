# Senemos Uke Kernel

Linux kernel adaptations and Fedora Rawhide AArch64 packaging for Xiaomi Pad 7
and POCO Pad X1 (`uke`, Qualcomm SM7675).

**Source branch** [7.3.5](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/7.3.5)

**Published build** [7.3.5-46, COPR 11372350](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11372350/)

| Path | Contents |
| --- | --- |
| [kernel/configs/](kernel/configs/) | ARM64, board, feature and native configuration |
| [kernel/overlay/](kernel/overlay/) | Uke sources at their Linux paths, including device trees and bindings |
| [kernel/patches/](kernel/patches/) | Subsystem patches and ordered base and release-delta series |
| [boot/](boot/) | Boot image and initramfs sources |
| [packaging/rpm/kernel/](packaging/rpm/kernel/) | RPM recipe, signed parent plan and verified inputs |
| [tools/](tools/) | Build environment and release tooling |
| [tests/](tests/) | Source layout checks and display fixtures |

The release uses the `senemos-uke-linux-kernel-mainline` RPM family. Match the
kernel, modules and boot payloads when updating. See the
[Uke Linux project](https://github.com/MCC45TR/uke-linux) for supported images,
recovery and hardware status.

[Architecture](docs/architecture/source-layout.md) ·
[COPR build guide](docs/development/building.md) ·
[Hardware and interfaces](docs/hardware/overview.md) ·
[Release notes](docs/releases/7.3.5-46.md)

Use [GitHub Issues](https://github.com/MCC45TR/senemos-uke-kernel-mainline/issues)
for reproducible bugs and [SECURITY.md](SECURITY.md) for security reports.

Project scripts and documentation use the [MIT License](LICENSE). Linux
sources and derived patches retain their original licenses and SPDX notices.
