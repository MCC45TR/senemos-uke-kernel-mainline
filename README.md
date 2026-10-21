# Senemos Uke unstable mainline kernel

21 October 2026 · Xiaomi Pad 7 / POCO Pad X1 (`uke`, SM7675) · Fedora Rawhide AArch64.

This branch packages signed upstream Linux 7.3 as RPM version `7.3.0`, with
99 Uke adaptation patches and the native O82 display profile. The module and
boot release is `7.3.0-1-unstable`, separate from the ordinary mainline family.

[Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Native build 11183784](https://copr.fedorainfracloud.org/coprs/build/11183784/) · [Source lock](manifests/linux-7.3.0.json) · [Source profile](packaging/native/README.md) · [Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support)

## Packages

| Package | Contents |
|---|---|
| `senemos-uke-linux-kernel-mainline-unstable` | Exact common kernel package set |
| `senemos-uke-linux-kernel-mainline-unstable-core` | AArch64 Image, configuration and source identity |
| `senemos-uke-linux-kernel-mainline-unstable-modules` | Matching modules for the unstable ABI |
| `senemos-uke-linux-kernel-mainline-unstable-dtbs` | Uke device tree and native display overlay |
| `senemos-uke-linux-kernel-mainline-unstable-boot` | Linux/userdata Android v4 containers and matched inventories |

The separate `senemos-uke-linux-kernel-mainline-unstable-singleboot` package
selects the exact userdata image through its own descriptor and symlink.
Installation performs no kernel activation, storage write, slot selection or
reboot. Existing kernels and the ordinary boot default remain independent.

The retained Uke RPMh backend does not implement upstream's new read
transaction. It returns `-EOPNOTSUPP` without accessing hardware. The custom Uke
regulators retain their existing implementation; generic RPMh consumers that
require initial-state reads remain unavailable under this backend.

Source preparation, selected AArch64 objects and actual-source host fixtures
pass. Native package results, signed-artifact checks and physical acceptance
remain distinct. This kernel has no tablet boot or hardware qualification.
Earlier mainline results retain their exact identities in the
[previous source record](https://github.com/MCC45TR/senemos-uke-kernel-mainline/blob/a510196b386a6474afc7b8590d985446c1eac318/README.md).

## Source build

```sh
git clone --branch copr/mainline-unstable https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
cd senemos-uke-kernel-mainline
make validate
make srpm
```

The source producer verifies the pinned upstream archive signature and retains
patch/configuration hashes, source identity and native contract tests. No OEM
firmware, credentials or device-private calibration is a source input. The
upstream MSM XML/header generator is a documented host-only Python dependency;
project tablet and initramfs payloads exclude Python.

Project tooling uses [MIT](LICENSE). Linux code and derived patches retain
their original SPDX and GPL-compatible licenses and attribution.
