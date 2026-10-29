# Senemos Uke Mainline Kernel

Linux kernel adaptations, device trees and Fedora RPM packaging for Xiaomi Pad 7 and POCO Pad X1 (`uke`, Snapdragon 7+ Gen 3 / SM7675).

**Target:** Linux 7.3.x · AArch64 · Fedora Rawhide  
**Status:** Active development

[Uke Linux](https://github.com/MCC45TR/uke-linux) · [Hardware support](https://github.com/MCC45TR/uke-linux#hardware-support) · [COPR packages](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Build documentation](docs/BUILDING.md)

> [!WARNING]
> This is an experimental kernel. Keep a working boot image and matching modules before updating. Not every source change has been tested on the tablet.

## Development status

**Last documented device check: 28 October 2026 — POCO Pad X1.**

The signed `7.3.0-33` package set was installed through DNF and successfully booted from slot B. Boot-image readback, matching modules and external boot-health checks passed. The existing Android boot slot A was left unchanged.

The release also includes touchscreen changes aimed at improving multitouch and tap handling. Earlier focused tests showed improvements, but full physical input validation on `7.3.0-33` is still pending. The KDE desktop selection issue and Focus Pen/Focus Keyboard support also remain open.

Native display output, the Fedora KDE desktop and basic device operation have been demonstrated. VRR, external display features, sleep, charging protection and long-term stability still need further testing. For the current peripheral-by-peripheral status, see the [Uke Linux hardware table](https://github.com/MCC45TR/uke-linux#hardware-support).

The normal boot path currently enters **EL1**. EL2/KVM work is maintained separately and is not part of the validated Fedora boot path.

## Install on Fedora

Development RPMs are published to [COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/). On a configured Fedora Rawhide AArch64 installation:

```bash
sudo dnf copr enable mcc45tr/uke-linux-test
sudo dnf --setopt=installonly_limit=0 install senemos-uke-linux-kernel-mainline
sudo dnf --setopt=installonly_limit=0 upgrade 'senemos-uke-linux-kernel-mainline*'
```

The kernel, modules, device trees and boot image must use matching versions. The boot updater is opt-in: installing RPMs alone does not enable automatic partition writes or switch boot slots. When explicitly enabled and its checks pass, it writes and verifies **slot B** while preserving the previous boot image. Review the update procedure before enabling it.

### RPM packages

| Package | Purpose |
| --- | --- |
| `senemos-uke-linux-kernel-mainline` | Kernel package set |
| `senemos-uke-linux-kernel-mainline-core` | ARM64 kernel image, configuration and metadata |
| `senemos-uke-linux-kernel-mainline-modules` | Matching kernel modules |
| `senemos-uke-linux-kernel-mainline-dtbs` | Uke device trees and display overlay |
| `senemos-uke-linux-kernel-mainline-boot` | Matched Android boot image and boot metadata |

## Build from source

```bash
git clone https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
cd senemos-uke-kernel-mainline
make validate
make srpm
```

`make validate` checks the pinned source profile, patches, configuration and package contracts. `make srpm` verifies the upstream source archive and signature, then prepares the native source RPM. These steps do **not** establish that a kernel boots or works on the tablet.

The older `senemos.sh` build entry remains available for legacy and diagnostic workflows. It does not reproduce the current consolidated native boot image. See [BUILDING.md](docs/BUILDING.md) and the [native source profile](packaging/native/README.md) for prerequisites and supported build paths.

## Branches

| Branch | Purpose |
| --- | --- |
| [`main`](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/main) | Integrated Linux 7.3 kernel and singleboot packages |
| [`KVM`](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/KVM) | Experimental EL2/KVM development |
| [`UNSTABLE`](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/UNSTABLE) | Linux 7.4 release-candidate work, gated on a reviewed source profile |

Previous branch tips are archived under `archive/2026-10-29/` tags. Singleboot is a package profile, not a separate branch.

## Documentation

- [Source manifest](manifests/linux-7.3.0.json) — upstream version, patches and checksums
- [Build guide](docs/BUILDING.md) — local builds and tooling
- [Native packaging](packaging/native/README.md) — source integration and package details
- [Architecture](docs/ARCHITECTURE.md) — kernel integration overview
- [Automation](docs/AUTOMATION.md) — source updates and COPR workflow
- [Reports](reports/) — technical findings and validation records

Bug reports should include the device, kernel version, steps to reproduce and relevant logs. Use [GitHub Issues](https://github.com/MCC45TR/senemos-uke-kernel-mainline/issues) for bugs and [SECURITY.md](SECURITY.md) for security reports.

## License

Project scripts and documentation are available under the [MIT License](LICENSE). Linux kernel code and derived patches retain their original licenses and SPDX notices.
