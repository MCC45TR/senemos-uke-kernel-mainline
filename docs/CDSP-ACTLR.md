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

COPR11261896 succeeds for exact source3776f776b5be22d01e4bb084cff994050c719a2e.
The original allocator fails its required assertion, all four GCC/Clang ordinary
and ASan/UBSan callback runs pass, all four mutants are refused, retained video
controls pass, and the real AArch64 SMMU object includes the new initialization
callback at -Werror with unchanged configuration. Inherited touch/geometry/GMU
preparation and the real MSM composite also pass. Prepared SMMU source SHA is
4ff6bd3c30fa30f949f7f6c11a02f9e11abb687f15afa67d61bfb4c5731c499e; object SHA
2379b34de1a4a60f43189eaf4d36a33a7729e5dde0dd2fa56e511dbbb956a9f6.
The complete text-receipt RPM passes both full-fingerprint OpenPGP signatures
and header/payload digests; its exact source and five assertion controls match.
It is not installed. The reused factory retains kernel-family Conflicts, which
is another reason this text fixture is evidence rather than a device package.
Full kernel delivery and physical translated computation remain open.
