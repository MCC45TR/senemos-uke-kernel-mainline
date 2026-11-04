# GMU fault IRQ and polled response ownership

5 November 2026. POCO Pad X1 on11003 logs one GX_BW_PERF_VOTE response timeout
followed by the same late response sequence. A fault IRQ can acknowledge that
response before its synchronous poller sees it. This candidate corrects the
source-level ownership defect; it does not establish the cause of every stall.

## Exact comparisons

The measured runtime uses Adreno732/gen71100. The eight supplied OEM component
trees omit graphics-kernel. Uke MiCode kernel5712080a4b0c retains an older DRM
frontend; shared Xiaomi KGSL source
[ed4ad0d](https://github.com/LineageOS/android_kernel_xiaomi_sm8635-modules/blob/ed4ad0d1ad00b755af2fe61387dcc5397ad20b8f/qcom/opensource/graphics-kernel/adreno_gen7_hfi.c)
uses a separate queue/IRQ architecture and clears its handled HFI mask.
Its board values, firmware and full handler are not transplanted.

[KettleLinux91e3b5c, patch1350](https://github.com/kettlelinux/kettlelinux/blob/91e3b5cfe90925d469430fc915101df5579b4e68/kernel/patches/40-kettle/1350-drm-msm-a6xx-hfi-irq-clears-only-the-cm3-fault.patch),
attributed to gennro, reports the same loss on A740. The active queue also
contains an early interrupt-mask patch and a bounded-coredump patch. They are
separate changes and are not included here. Palawan/Lamma0d9f7fdf720ae9f4ecfbee4fadaf1e3b5c442e95,
declared Linux7.3.1 base79a907609d53d5cd645b42c11550d295d43abf99 and current
upstream05441d697f7f9a927264f4058cbbc6a03dfcac9d retain the greedy acknowledgement.
All sources retain their GPL licenses. This is a shared GMU register/ownership
comparison; other-device results are not Uke physical acceptance.

## Change and qualification

`0075-gmu-hfi-irq-owned-status.patch` masks the observed status to CM3_FAULT
before the existing write-one-to-clear call. Logging and fault recovery remain.
MSGQ and OOB acknowledgement bits remain for their synchronous owners. A new
fault arriving after a zero snapshot also remains pending. No IRQ-mask setup,
clock, OPP, firmware, polling limit, recovery lock or DT value changes.

The independent producer reuses the existing text-only `uke-o82-kms-check`
family. It verifies the complete qualified12101 SRPM header/payload and upstream
archive, preserves the active A732 adaptation for the selected files, and
rejects an unreviewed native-profile callback override. Only the four required
source files enter the slim fixture archive; a complete Linux archive is not
duplicated. This is callback extraction, not a complete prepared/linked kernel.

The fixture compiles actual `a6xx_hfi_irq` and
`a6xx_hfi_wait_for_msg_interrupt`, with modeled write-one-to-clear latches and
deterministic IRQ/poller ordering. The original source must fail the independent
pending-response assertion134. Corrected GCC/Clang normal and fail-fast ASan/
UBSan runs require all latch bits, mixed statuses, simultaneous and late faults,
OOB preservation, real missing-response timeout and the original completion
retry. Register facts come from the pinned kernel XML using native awk; no
Python generator or device compilation is needed.

Source/syntax checks and remote native qualification remain pending. The patch
must join the coordinator's next complete cumulative unstable candidate,
retaining touch ordering, SSC, camera quarantine and every other feature/gate.
Complete linked-object/module/package qualification, signed DNF delivery and
physical recurrence/wake/display acceptance remain required. No performance
governor workaround, independent kernel delivery, device reset or stress test
follows from this source contribution. Canonical record:
UKE-GMU-IRQ-20261105-01 in the workspace knowledge repository.
