# Senemos Uke Mainline Kernel

Mainline Linux kernel development for **Xiaomi Pad 7** and **POCO Pad X1**
(`uke`, Qualcomm SM7675). This repository maintains the Uke platform patches,
device tree, configuration and Fedora packaging needed to advance the port
through reviewed upstream stable releases.

**Current development profile:** Linux **7.2.9** · **AArch64** · **Fedora Rawhide**

[Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Source profile](manifests/linux-7.2.9.json) · [Hardware status](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md) · [Build records](https://github.com/MCC45TR/uke-fedora-builder/tree/main/reports) · [Uke Linux project](https://github.com/MCC45TR/uke-linux)

## Project status

The Uke adaptation has produced an ARM64 kernel Image, an independent Uke DTB,
matching modules and Fedora RPM/SRPM packages. Local source verification,
compilation, module ABI and package lifecycle checks have separate records.
Native AArch64 builds are published through the development COPR.

**Physical boot and peripheral support are still untested.** Packages are
development candidates. A complete Fedora system image and qualified UEFI boot
integration remain later milestones. Compatibility is recorded separately for
each model, SKU, installed firmware and hardware variant in the
[device matrix](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md).

| Area | Current scope |
|---|---|
| Upstream source | Signed Linux 7.2.9 release with a pinned source identity |
| Platform adaptation | Seven attributed patches covering clocks, RPMh regulators, pin control, USB interconnect, scoped SMMU handoff, USB integration and the Uke DTS |
| Device tree | Independent compile-stage Uke description; firmware-specific RAM and dynamic reservations still require boot handoff validation |
| Fedora packages | Kernel, modules and DTB packages for Rawhide AArch64, with source and build metadata |
| Display, touch, GPU and storage | Further Uke driver and device-tree work; no own-device acceptance |
| Wireless, audio, sensors, charging and suspend | Tracked individually in the device matrix; no own-device acceptance |

Compiled drivers and a compiled DTB establish buildability. Their runtime
behavior needs firmware-matched boot and hardware tests. Unreviewed peripherals
remain disabled in the independent DTS. Xiaomi Pad 7 Pro (`muyu`) and Pad 5
(`nabu`) have separate platform requirements.

## Packages and installation

The [mcc45tr/uke-linux-test COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/)
provides the development packages and source RPMs. Its build history and logs
identify each submitted version and packaging revision. The current package
target is **Fedora Rawhide AArch64**.

| Package | Contents |
|---|---|
| `senemos-uke-linux-kernel-mainline` | Installs the matching core, modules and DTB package set |
| `senemos-uke-linux-kernel-mainline-core` | ARM64 Image, configuration, System.map and source identity |
| `senemos-uke-linux-kernel-mainline-modules` | Modules rebuilt for the same kernel and configuration |
| `senemos-uke-linux-kernel-mainline-dtbs` | Independent Uke device tree |

For an existing Fedora Rawhide AArch64 development environment:

```sh
sudo dnf copr enable mcc45tr/uke-linux-test
sudo dnf install senemos-uke-linux-kernel-mainline
```

To receive accepted package revisions from the enabled channel:

```sh
sudo dnf upgrade 'senemos-uke-linux-kernel-mainline*'
```

Kernel files live under `/usr/lib/modules/KERNEL_RELEASE/`; the current release
is `7.2.9-senemos-uke`. Package installation updates module dependency indexes.
It does not create a UEFI boot entry, select a kernel or write Android
partitions. Firmware provisioning and boot selection require their own reviewed
integration. Kernel development headers are a later milestone.

COPR signs distributed RPMs with the project repository key. Verify the
configured repository key and package identities before evaluation. Package
signatures and upstream source signatures have separate roles; neither is a
tablet boot acceptance result. See the
[package hub](https://github.com/MCC45TR/uke-linux/blob/main/docs/PACKAGE-HUB.md)
for related Uke components and their readiness.

## Stable release maintenance

The project will continue tracking **upstream stable Linux releases**, including
future version lines as their Uke adaptations are reviewed. The
[stable tracking workflow](.github/workflows/stable-and-copr.yml) checks
Kernel.org daily; reviewed changes on `main` also trigger COPR source builds.

Every new kernel version passes the same admission process:

1. Pin the release archive, SHA-256, upstream commit and accepted signing key.
2. Review and forward-port the Uke patch series against that exact release.
3. Update the version profile and configuration identities; resolve Kconfig
   dependencies and compile the Image, DTBs and matching modules.
4. Verify source RPM preparation, module ABI, payload contents and package
   installation, upgrade and removal. Collect the independent native COPR result.
5. Record boot and peripheral tests separately for each supported device profile.

A newly announced version needs its own `manifests/linux-VERSION.json` and
reviewed adaptation before automatic publication. Tracking stops with an
explicit error when that profile is missing. The previous accepted source and
artifacts remain available during the next port. The development channel's
hardware status advances only with device evidence.

Packaging fixes increase the RPM release. Revisions of one upstream kernel
replace each other because they share a module directory; different upstream
versions retain separate installonly paths. Keeping an older package does not
automatically create or validate a boot fallback. The
[automation guide](docs/AUTOMATION.md) documents source verification, webhooks
and build environment boundaries.

## Building from source

The [Uke Linux workspace](https://github.com/MCC45TR/uke-linux) contains the
`senemeos.sh` host build entry. After preparing that workspace, run from its root:

```sh
./senemeos.sh --build 7.2.9 --distro=fedora --test
./senemeos.sh --build latest --distro=fedora
```

The builder verifies signed source, applies the exact Uke patch/config profile,
uses a containerized toolchain and records the resulting Image, DTB, modules,
RPMs and SRPM. Concurrency follows available host resources; cached source and
build state are retained. `latest` resolves upstream stable and requires a
reviewed Uke profile. Other distribution targets have separate readiness gates.
See the [builder guide](https://github.com/MCC45TR/uke-fedora-builder/blob/main/docs/BUILDING.md)
for host prerequisites, offline operation and test scope.

For source package work within this repository:

```sh
make validate
make srpm
```

`make validate` checks the reviewed patch and configuration hashes. `make srpm`
downloads the pinned upstream archive when needed, verifies its checksum and
detached OpenPGP signature, and creates an AArch64 source RPM. Binary compilation
and hardware validation are separate steps.

## Source layout and provenance

| Path | Purpose |
|---|---|
| [`manifests/`](manifests/) | Exact upstream source, patch and configuration identities |
| [`patches/7.2.9/`](patches/7.2.9/README.md) | Ordered Uke adaptation with donor attribution and porting notes |
| [`configs/`](configs/) | ARM64, Uke and Fedora configuration fragments; upstream verification key |
| [`packaging/`](packaging/) | Kernel RPM rules and package lifecycle behavior |
| [`.copr/`](.copr/) | COPR source package generation |
| [`.github/workflows/`](.github/workflows/) | Source validation and stable release tracking |
| [`docs/`](docs/) | Architecture and automation documentation |
| [`reports/`](reports/) | Reviewed build evidence |

The adaptation draws on the attributed
[Uke Linux 6.12 community port](https://github.com/ztsubaki/uke-linux) and
firmware-specific OEM research. Changes are reviewed against current upstream
interfaces, and drivers are rebuilt for the target kernel ABI. Android vendor
modules are not included in the mainline packages. Source attribution and
original file licenses are preserved in the patch series.

Linux 7.2.8 is retained as the
[historical generic buildability baseline](reports/BASELINE-BUILDABILITY.md).
That baseline predates the independent Uke DTB. Source/build, package,
emulation and physical-device evidence are recorded separately; see the
[engineering lessons](https://github.com/MCC45TR/uke-linux/blob/main/docs/lessons/PLATFORM-INDEX.md).

## Contributing and security

Contributions should identify the upstream base, subsystem, device/firmware
scope and validation performed. Keep patches focused, preserve attribution and
report source, build, package and hardware results distinctly. Development code
belongs in project sources or patches; reference archives remain unchanged.
Read the [project contribution rules](AGENTS.md) and
[kernel architecture](docs/ARCHITECTURE.md) before changing the port.

Use [GitHub issues](https://github.com/MCC45TR/senemos-uke-kernel-mainline/issues)
for ordinary bugs with public reproduction details. Follow the
[security policy](SECURITY.md) for vulnerabilities and private data handling.

Project-authored repository tooling and documentation use [MIT](LICENSE).
Linux sources and derived kernel patches retain their original SPDX and
GPL-compatible licenses; consult each file and the source package's notices.
