# Uke CDSP context setup

5 November 2026, POCO Pad X1, running7.3.1-12101-unstable/sourcebba194e.
The prepared exact stock firmware passes local metadata/MCU/TA hash checks.
Manual CDSP secure startup succeeds, GLINK registers both FastRPC devices,
and normal remoteproc stop succeeds and removes them. Both context banks
currently fail the boot SMMU's ACTLR refusal. No DMA or compute was attempted.
Device nodes alone do not establish a usable compute session.

The exact Uke OEM DT94c84aeb, qcom/msm-arm-smmu-cliffs.dtsi, and the live
qcom,actlr table agree: unmasked SIDs0xc01/0xc02 each require0x303. The same-SoC
OnePlus modules/DT1138e00f contains the same two rules in
kernel_platform/qcom/proprietary/devicetree/qcom/msm-arm-smmu-cliffs.dtsi.
Uke kernel5712080a's qsmmuv500_device_group/qsmmuv500_init_cb applies the
per-stream ACTLR at context initialization. These are GPL-2.0 source comparisons;
no donor program or board configuration is executed or transplanted.

[Upstream context setup](https://github.com/torvalds/linux/blob/master/drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c)
also applies ACTLR during initialization. The
[upstream discussion](https://lists.infradead.org/pipermail/linux-arm-kernel/2025-November/1084122.html)
explains why a generic FastRPC compatible alone cannot authorize a uniform
setting across ADSP, CDSP and SoCs. This contribution retains the exact Uke
board, boot SMMU, native OF path and one unmasked SID. Each domain requires
one exact OEM0x303 rule; missing, malformed, broad, conflicting or duplicate
matching rules are refused before allocating a bank. No other context is added.

src/cdsp/apply-actlr.sh applies patches/cdsp/0001-uke-cdsp-actlr.patch to an
already prepared cumulative kernel and installs uke-cdsp-smmu.c. It runs only
off-device in COPR. The allocator keeps generic fresh-bank selection and all
boot-bank reservations. Setup requires S1, at least32 input-address bits and
a non-boot bank, then verifies0x303 readback before generic translation starts.
Non-CDSP initialization still delegates to the existing video/display path.
Secure-channel policy, both admitted SIDs, PAS lifetime, memory reservations,
VMIDs, DMA geometry and failed-stop ownership remain unchanged.

The independent fixture producer reuses the hash-pinned e6c122e composite
factory with its own fixture package identity and intact namespace guard.
It retains complete12101, touch, geometry and GMU preparation. Original allocator
failure, actual positive/negative callbacks, GCC/Clang sanitizer runs, required
mutants and a real AArch64 SMMU object are required. It packages text receipts
only. Newer memory/v5 and other contributions remain mandatory in the
coordinator's final cumulative kernel; this fixture does not replace that queue.

Full kernel integration, signing, delivery and physical translated-buffer/RPC
and output-checked computation remain separate gates. No kernel installation,
profile selection, AP reboot, automatic boot or stable promotion is performed
by this contribution. Keep automatic staging enabled and preserve the existing
local rollback preference. Both full calibrated cameras and rear focus remain
required independently.
