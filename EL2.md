# Experimental EL2 and KVM bring-up

The target is a Linux host with usable KVM on Uke/SM7675. **Physical EL2 boot is
blocked by the firmware handoff.** This branch does not change ABL, HYP, TrustZone
or any partition. It must not replace the working branch or trigger production
COPR builds before the firmware contract and physical acceptance are complete.

The reviewed COPR 1.25 boot candidate already has `CONFIG_VIRTUALIZATION=y` and
`CONFIG_KVM=y`. Earlier physical Uke logs show `All CPU(s) started at EL1` and
`HYP mode not available`. An image name, command-line flag or kernel config cannot
turn that handoff into EL2. Linux supports entry at either EL1 or EL2; KVM needs
access to EL2. The host kernel can subsequently run at EL1 with nVHE, so measuring
the running kernel's exception level alone is insufficient.

See the [Linux boot requirements](https://docs.kernel.org/arch/arm64/booting.html)
and [KVM HYP ABI](https://www.kernel.org/doc/html/v7.2/virt/kvm/arm/hyp-abi.html).
Qualcomm's [KVM guide](https://docs.qualcomm.com/bundle/publicresource/topics/80-70022-3/virtualization.html)
describes supported developer BSPs, not an established Xiaomi Uke boot contract.
The [Radxa secure-launch research](https://github.com/TravMurav/Qcom-Secure-Launch)
is a comparison source; its DT properties and SMC calls are not Uke instructions.
Qualcomm's [early Gunyah exit proposal](https://lists.u-boot-project.org/pipermail/u-boot/2026-May/618680.html)
identifies an SMC transition used by some developer platforms. The
[maintainer review](https://lists.u-boot-project.org/pipermail/u-boot/2026-May/618951.html)
explicitly asks which platforms support it. Neither establishes support in
Xiaomi's signed Uke firmware; this branch does not issue that call.

Read-only recovery inspection on 12 October matched all six reviewed B-slot
payloads to OS3.0.304.0.WOZMIXM, including zero partition padding. All six active
A-slot payloads differed. Independent device hashes verified the captures.
The offline archive therefore describes the retained B slot, not the active
firmware tuple. No slot or firmware was changed during this inspection.

## Native acceptance probe

On an AArch64 build host, run `make kvm-probe`. The C++ probe uses the standard
Linux KVM ABI to create one VM, one vCPU and 4 KiB of anonymous guest memory.
A tiny AArch64 guest writes a known value to an unmapped MMIO address. Only the
matching `KVM_RUN` exit produces `kvm-guest-pass`. There are no disks, guest device
passthrough, physical memory mappings or firmware calls. Execution is bounded by
a ten-second alarm. Process exit releases the VM and memory.

Run `build/kvm/uke-kvm-probe` on the tested host, with permission to access
`/dev/kvm`. Exit 0 means the guest ran; exit 2 means `/dev/kvm` is unavailable;
exit 3 means an architecture, permission, ABI or execution error; exit 64 rejects
arguments. A missing or inaccessible node is never treated as an EL2 success.

## Acceptance before an EL2 boot image can be released

1. Match the installed Uke ABL/HYP/UEFI hashes to a reviewed source/firmware tuple.
2. Establish an exact Uke firmware-supported EL2 transfer or takeover protocol,
   including all CPUs, RAM reservations, interrupt-controller and SMMU ownership.
3. Preserve a tested Android/recovery return route and existing ESP/Linux GPT.
4. Test an isolated RAM boot; collect boot-level and KVM logs and a passing guest.
5. Recheck UFS, USB, display, WPSS/ADSP firmware services and reboot behavior.

Generic ARM64 emulation can validate the probe and distinguish EL1 from EL2
fixtures. It cannot establish Uke firmware ownership or physical support.
