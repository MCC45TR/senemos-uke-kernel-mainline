# Linux 7.3 Uke KVM candidate

25 October 2026. Fedora Rawhide AArch64 source and COPR build preparation.
No tests, tablet installation, boot or guest execution were requested for this
preparation. All physical acceptance remains open.

The source is based on `c4feee0d717770f909a08038af51058ed806d747`, the current
Linux 7.3 native source branch, retaining its display, touch, USB, audio and
RGB adaptations. Upstream Linux 7.3 is pinned to
`c03c1a14507dfaf8b856c2608f9ac216021fc222`; the archive's signature and hashes
remain mandatory production checks. The distribution version is `7.3.0`.

| Profile | Entry behavior | Admission |
| --- | --- | --- |
| `normal` | Original Linux entry, KVM only if firmware supplies EL2 | Source build supported |
| `el2-require` | Require existing EL2 on primary and every secondary; park on refusal | Default KVM candidate; no firmware call |
| `el2-exit-experimental` | Retained early Qualcomm SMC research | Build refused: no accepted Uke firmware contract |

`el2-require` cannot turn an EL1 boot into EL2. On the historically recorded
EL1 firmware handoff it will park before Linux starts. It is not an ordinary
desktop update. Do not install or activate it without an authorized recovery
window and a reviewed current firmware identity. Firmware support is unknown,
not proved absent. The retained early-exit source is not enabled by this build.

Use `make srpm el2_profile=el2-require run_tests=0` for the explicitly requested
build without tests. The generated spec carries that choice into source
preparation, boot compilation and `%check`. Integrity, privacy and payload
admission checks remain enabled. Tests are enabled by default for later builds.
Different profiles must use different RPM releases when published: RPM EVR,
`uname -r` and `/usr/lib/modules/` are separate fields. Do not publish distinct
payloads under an existing RPM tuple.

The single KVM family is `senemos-uke-linux-kernel-mainline-kvm`; its six child
packages share exact dependencies and the `7.3.0-1-kvm` module ABI. The current
updater already recognizes `-kvm`. Legacy `-kvm-exit` packages are not used.
No install script writes a boot partition or selects a slot. The singleboot
alias is `kvm-default-boot.img`; the ordinary default alias is untouched.
`el2-build.json` in each bundle binds the source, profile, resolved config,
Image, module inventory, DTB and embedded initramfs hashes. The existing
updater manifest format and its rollback/module requirements are preserved.

Early refusal exposes debugger registers only: `x0` reason (1 entry EL,
2 arguments, 3 MMU/cache, 4 no transfer, 5 active stage-2, 6 secondary EL),
`x9` last checked register, `x21` MPIDR, `x22` stage (1 entry, 2 before SMC,
3 returned SMC, 4 EL2 checks), `x23` raw returned SMC x0 and `x24` return flag.
These are not persistent logs. No unqualified UART address or memory carveout
is written. A non-returning SMC remains unobservable without independent
early-boot instrumentation. Existing pstore does not close that gap.

The native `uke-kvm-probe` remains an explicit, argument-free RAM guest.
Exit 0 means the expected guest MMIO executed, 2 means no KVM, 3 is an error,
64 is invalid usage, and 124 is its structured ten-second timeout. A node or
API version alone does not prove guest execution. The probe never runs during
package installation or this build without tests. `uke-el2-status` reads current
boot/config/API state; it never runs a guest and reports guest status as untested.

## Waydroid preparation

Binder IPC and BinderFS are built in, with no global default Binder devices;
the container allocates its own devices through BinderFS. Existing memfd,
namespaces, cgroups, PSI, networking and DRM remain available. This is kernel
preparation, not a container, GPU or Android application result. Waydroid runs
as a native container and does not require KVM.

Use the original Fedora Waydroid package and official AArch64 image when its
installation is authorized; do not fork KDE or introduce project Python.
The upstream Waydroid manager and container service use Python. The project's
restriction on Python startup services needs an explicit policy decision
before installation. No Waydroid runtime, image or service is deployed here.

Next authorized session: identify the current firmware/boot/RPM tuple and
rollback, review EL2 admission, then evaluate all-CPU entry, KVM API, the native
probe, one/two-vCPU Linux guests, host peripherals and repeated boots in order.
Evaluate Waydroid's Wayland session, BinderFS, enforcing SELinux, native GPU,
network, audio and input separately. Full guest scripts already exist on the
builder's retained `experiment/el2-kvm` branch and must use KVM only.
