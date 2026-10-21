# Senemos Uke unstable singleboot profile

21 October 2026 · Xiaomi Pad 7 / POCO Pad X1 (`uke`, SM7675) · Fedora Rawhide AArch64.

`senemos-uke-linux-kernel-mainline-unstable-singleboot` selects the userdata
boot image from the exact `7.3.0-1` unstable kernel package set. Upstream Linux
7.3 is represented as RPM version `7.3.0`. This metadata package shares the
common Image, modules, device tree and boot payload; it does not rebuild Linux.

[Development COPR](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/) · [Package specification](packaging/senemos-uke-linux-kernel-mainline-unstable-singleboot.spec) · [Profile descriptor](packaging/singleboot.json) · [Hardware status](https://github.com/MCC45TR/uke-linux#hardware-support)

The package installs `/usr/share/senemos/uke/unstable-singleboot.json` and
`/usr/lib/senemos/unstable-default-boot.img`. The symlink selects
`kernel-updates/7.3.0-1-unstable/userdata.img` with `senemos.root=userdata`.
The ordinary default boot image remains independent.

Installation performs no boot activation, storage write, slot selection or
reboot. Kernel boot, power behavior, image composition and physical acceptance
remain unqualified. The retained Uke RPMh backend does not support upstream's
new read transaction; the unstable kernel explicitly returns `-EOPNOTSUPP`.
Earlier mainline tablet results do not qualify this version.

## Source build

```sh
git clone --branch copr/mainline-unstable-singleboot https://github.com/MCC45TR/senemos-uke-kernel-mainline.git
cd senemos-uke-kernel-mainline
make singleboot-srpm
```

The host contract checks the exact dependencies, descriptor and independent
boot symlink. COPR builds this profile after its matching native unstable kernel
succeeds. Signed-artifact checks and tablet validation are separate stages.
See [the profile record](packaging/SINGLEBOOT.md) for package boundaries.

Project metadata and tooling use [MIT](LICENSE). Linux and derived patches
retain their original licenses and attribution.
