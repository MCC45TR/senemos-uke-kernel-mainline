# Uke EL2 and KVM experiment

18 October 2026. Target: POCO Pad X1 / Xiaomi Pad 7, SM7675, Fedora Rawhide
AArch64. This branch integrates main at
`dfc8511b5107f867aebf59197dffadd110228875` (Linux 7.2.11, 77 base patches).
The current display, USB, CPU/GPU and sensor source profile is retained.
**Physical Uke EL2 boot and the firmware service remain unqualified.**

## Produced configurations

| Build | Package and module namespace | Early behavior |
|---|---|---|
| Default | `uke-senemos-kernel-mainline-kvm`, `7.2.11-2-kvm` | Observe the firmware entry; no takeover SMC. KVM works only if firmware already supplies EL2. |
| Explicit `rpmbuild --with gunyah_exit` | `uke-senemos-kernel-mainline-kvm-exit`, `7.2.11-2-kvm-exit` | Require EL2, attempting the Qualcomm early exit only from EL1. Experimental; not admitted for a Uke boot trial. |
| `CONFIG_QCOM_UKE_EL2_ENTRY=y`, exit disabled | Manual diagnostic source configuration | Require existing EL2 on primary and secondary entry; issue no takeover SMC. |

Both RPM variants contain matching Image/modules/config/DTB/native overlay and a
source-generated Android v4 boot container. Installation has no boot scriptlet,
slot selection or production-updater invocation. The experimental package is
not on the production updater's allowlist. Building a container does not
establish that stock ABL accepts its early transfer or that the tablet boots.
Use one namespace per configuration; never substitute these modules into an
accepted normal-kernel directory. Keep Android A, boot B, `PARTLABEL=linux`,
original early firmware and the accepted image/module fallback.

`make validate`, `make kvm-probe` and `make srpm` are host operations. The SRPM
producer verifies the pinned kernel archive/signature and source-asset hashes.
Rebuild the resulting SRPM in a Fedora Rawhide AArch64 RPM worker. The historical
`senemos.sh --build` binary producer is explicitly refused on this experimental
branch because it packages the earlier normal-kernel recipe; its inspection,
version-resolution dry run and self-tests remain available. It cannot silently
produce a normal kernel under an EL2 request.
The upstream MSM XML register generator is the documented host-only Python
build dependency in `packaging/native/README.md`. No project Python, runtime,
firmware, credentials or device calibration belongs in the tablet payload.

## Early entry implementation

`src/boot/uke-el2-entry.S` is integrated by
`patches/boot/0004-uke-el2-entry.patch` and `prepare-el2-source.sh`, before
`record_mmu_state` and Linux exception-register initialization. Both Kconfig
symbols default off. Only the explicit `-kvm-exit` build enables the SMC.

The implementation preserves x0/FDT and the return address in callee-saved
registers without a stack, heap or MMIO access. From EL1 it requires aligned,
nonzero FDT, zero x1-x3, masked DAIF and disabled MMU/data cache. It uses the
Qualcomm ABI documented in the pinned Kodiak and U-Boot sources. After a
return it requires actual EL2, disabled EL2 MMU/data cache and inactive CPU
stage-2 before restoring the Linux boot arguments. Existing EL2 entry skips
the call. Secondary CPUs must enter at EL2 through PSCI; they never repeat a
global hypervisor exit.

A failed check parks with interrupts masked. `uke_el2_refused` retains x0 as
reason and x9 as the last inspected register: 1 wrong primary EL, 2 boot
arguments/DAIF, 3 MMU/cache, 4 returned without EL2, 5 active stage-2, 6 wrong
secondary EL. No reset SMC, guessed firmware fallback or continuation into EL1
is attempted after a partial transfer. A call that never returns cannot be
recovered by this code or a userspace watchdog.

This is an implementation of an **unqualified firmware candidate**, not proof
that Uke implements its ABI. `manifests/el2-research-20261018.json` retains an
empty firmware allowlist. The stripped OEM TZ ELF has no section/symbol table;
bounded static inspection has not established service availability, complete
call semantics or CPU return behavior. Firmware strings and constants alone
are insufficient. Do not use this image on hardware until the following
ownership contract is resolved.

## Firmware and device contract still required

| Area | Required Uke evidence |
|---|---|
| Firmware identity | Current slot, model/SKU, exact ABL/HYP/TZ/UEFI/UEFISECAPP/XBL payload length/hash, full partition hash and padding separately; rollback constraints and matching archive. The 12 October B-slot comparison is historical. |
| Service support | Exact installed firmware's supported early-exit ABI, availability policy, return values/state, preserved registers and behavior on failure. No guessed discovery call from a running Linux host. |
| RAM and entry | Loaded Image/FDT addresses, image extent, cache-to-PoC, boot CPU state, secure/carveout ownership, old Gunyah reservations and guest IPA limit. Do not reclaim reserved memory without evidence. |
| CPU/PSCI | All eight CPUs, SMC conduit, CPU_ON/OFF return at EL2, coherency, reset and resume. Boot-CPU success alone is insufficient. |
| GIC and timer | GICv3 redistributors and maintenance PPI 9; timer frequency/offsets, guest timer delivery and migration. Current Uke DT has four timer PPIs 13/14/11/12; Linux's fifth-IRQ fallback is not physical timer qualification. |
| DMA/SMMU | Quiesced DPU/GPU/GMU/UFS/USB/WPSS/ADSP masters and exact stream/domain ownership. Kodiak describes SMMU reset to bypass; Uke's current firmware-display handoff assumptions need a separate review. CPU stage-2 checks do not check SMMU. |
| Firmware services | SCM/PAS, AOSS/QMP, RPMh, remoteproc, sensors, charging and GPU firmware after the exit. Keep persist read-only and exact calibration. |
| Recovery | Independently available bootloader/recovery access, exact accepted image and matching modules, image hashes and a verified return procedure. A 180-second userspace observer cannot undo early lockup. |

Do not transplant WoA, Kodiak, QCS9100, Palawan, Peridot or Nabu addresses,
security firmware, partition geometry or calibration. `slbounce` explicitly
excludes Android devices; OpenABL/UEFI presence does not acquire EL2. A dedicated
EL2 DT variant must follow measured ownership differences; deleting Gunyah
reservations or disabling SMMU to make a test proceed is not an accepted fix.

## Tests and evidence boundaries

- `tests/el2-entry-qemu.sh build OUTPUT` compiles the actual early entry with
  Clang/LLD. `run OUTPUT` uses generic ARM64 TCG. Eleven cases cover existing
  EL2, EL1 refusal, argument/cache/stage-2 checks and secondary entry. An
  explicitly synthetic error-return case verifies that an unchanged EL1 is
  rejected. Generic QEMU's real vendor SMC does not return; its bounded timeout
  is recorded separately. No successful Uke firmware transition is simulated.
- `tests/kvm-probe-abi.cpp` checks the probe's ioctl/memory contract with
  synthetic 4/16/64 KiB host pages and error paths. It does not execute a guest.
- `tests/kvm-probe-contract.sh` checks actual arguments and the available host
  environment. `make kvm-probe` builds the native C++ helper. It creates one VM,
  one vCPU and one host page, runs known AArch64 code, and accepts only the
  expected MMIO write. No storage, passthrough or firmware call is involved.
  Exit 0 is a real guest result, 2 unavailable KVM, 3 ABI/permission/architecture
  error, 64 invalid arguments; a signal/timeout remains a separate failure.
- The builder's `tests/el2-kvm-qemu*.sh` retain the earlier disposable Fedora
  EL1/EL2 comparison. Their outer accelerator is TCG. Added Uke compatible
  strings select an adaptation path; they do not emulate Uke hardware.
- `src/kvm/make-guest-initramfs.sh OUTPUT` builds a RAM-only native ARM64 guest
  acceptance initramfs with libc and its loader; optional `OUTPUT probe` selects
  the real KVM probe as PID 1 and admits its libgcc cache-maintenance dependency.
  Dependencies and their transitive imports are restricted to that small list.
  `tests/el2-generic-qemu.sh` tests both payloads on a separately configured
  generic kernel from `configs/el2-qemu.config`. This removes the old Fedora
  fixture's disk/udev readiness from the KVM execution test. The builder's
  `tests/kvm-linux-guest.sh KERNEL INITRAMFS PROBE OUTPUT` requires actual
  `/dev/kvm`, uses only `-accel kvm`, and tests one then two vCPUs, timer wakeup,
  CPU migration and clean poweroff. No disk, network or TCG fallback is supplied.
  Use an ARM64 guest kernel that supports virt/GICv3/PL011/devtmpfs/proc/sysfs and
  external initramfs, with no forced internal initrd or command line.

Physical acceptance is sequential: K0 exact current boot/firmware tuple; K1
consistent all-CPU EL2 entry and positive HYP/KVM initialization; K2 KVM ABI;
K3 real MMIO probe; K4 one-vCPU Linux; K5 two-vCPU PSCI/GIC/timer/migration;
K6 host UFS/USB/display/Wi-Fi/ADSP/GPU/sensors/charging and reboot regressions;
K7 measured mixed load, thermal limits and repeated cold/reboot/rollback trials.
None of the source, package or generic-emulation tests closes K0/K1/K6/K7.

## Source attribution

The exact identities and bounded findings are in the research manifest.
The early-call ABI comes from Qualcomm's BSD-2-Clause-Patent
[Kodiak helper](https://github.com/tianocore/edk2-platforms/blob/1c500d13a653cf0f556ecf7ce703c12874247efc/Silicon/Qualcomm/KodiakPkg/Library/KodiakLib/KodiakHelper.S)
and Aswin Murugan's GPL-2.0-only
[U-Boot v5 proposal](https://mail-archive.com/u-boot@lists.u-boot-project.org/msg09190.html).
The project assembly adds explicit entry/refusal checks and retains GPL-2.0-only.
The [arm64 boot contract](https://docs.kernel.org/arch/arm64/booting.html) defines
required CPU, memory, DMA, cache, interrupt and timer state. These sources do not
claim Xiaomi Uke firmware support. Detailed trials and corrections belong in the
central private lesson journal; physical acceptance remains open.
