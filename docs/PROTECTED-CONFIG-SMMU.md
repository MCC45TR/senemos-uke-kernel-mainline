# Permanent Uke audio configuration SMMU admission

6 November 2026. Complete12213/COPR11271186 compiles the final-DT ordering
correction and passes827 module signatures, but remains uninstalled. Source
review finds that its root `/audio-config-memory` supplier cannot match the
existing `qcom_uke_hdmi_dma` frontend-only admission. APM waits for this supplier
before creating that frontend. The new check executes the actual original
allocator to reproduce refusal before any context allocation; this is source
control evidence, not a12213 hardware observation.

The GPL-2.0-only helper admits only the exact root supplier on xiaomi,uke /
qcom,sm7675, the protected APM graph and its available HDMI-marked frontend.
Both24-byte `iommus` properties must match: controller/0x1001/0x80 followed by
the same controller/0x1061/0. The encoded firmware IDs must be0x801001/0x1061,
and that controller must be the actual available boot SMMU with two cells.
No frontend platform device is needed during allocation. The original normal
translated allocator, ACTLR refusal and reserved contexts remain unchanged;
the permanent provider still checks actual group/domain equality on acquire.

The patch applies after all complete13 preparation, including actual CDSP
qualification. Exact pre/post hashes and inverse comparison restrict the
allocator delta to one include and one additional admission alternative.
GCC/Clang normal and ASan/UBSan fixtures execute the actual helper, original
sensor/HDMI predicates and actual allocator with synthetic OF/bitmap operations.
The original control and encoded-SID/frontend/controller mutants must hit
assertions. Malformed properties, foreign identity, ACTLR rules and failed
allocation refuse; existing ordinary streams and special delegation stay covered.
An actual cumulative AArch64 arm-smmu-qcom.o must contain this helper alongside
provider/APM/ABL/FastRPC objects; the full build also checks Image/vmlinux.
None establishes physical DMA, sound or speaker protection.

## Source comparison

Pinned inventory and the shared donor policy were consulted. Exact Uke DT
94c84aeb9e517dbde546fc732033c184094c8e57, `qcom/msm-arm-smmu-cliffs.dtsi`, and
same-SoC OnePlus DT1138e00fee63582a0cc6a53af3286621786827b7,
`kernel_platform/qcom/proprietary/devicetree/qcom/msm-arm-smmu-cliffs.dtsi`,
retain the same relevant boot-SMMU ACTLR table. Neither supplies an audio
0x1001/0x1061 override or this project-owned permanent provider. These files
lack a file-level license header; they are unchanged comparison inputs only.
No donor implementation, other-board address or new stream is transplanted.
The existing fitted frontend supplies the exact stream/property contract.

Current upstream f66469d9905b39d2c260a15d7d6db450f4db67c1,
`drivers/iommu/arm/arm-smmu/arm-smmu-qcom.c` (GPL-2.0-only) and
`sound/soc/qcom/qdsp6/q6apm.c` (GPL-2.0, Linaro), does not contain this Uke gate
or supplier. The23 September2026 v6 q6apm-dai memory-region proposal
(message20260923-vmid-v4-v6-3-3d61a0319b1c) distinguishes SMMU ADSP from
stage-2 mDSP carveouts; its carveout alternative is not this Uke contract.
No applicable queued permanent-Uke-provider admission was established.
References remain unchanged; failed guessed audio-DTS paths and recursive-tree
HTTP504 queries do not count as source review.

Complete13 DT/transport/lifetime/quarantine, private tuning, gain223, sensor,
USB/PM, camera admission, configs and automatic staging are retained. New
source check28 must qualify before a fresh full12214 reservation. Actual
provider/card/group readiness, protected configuration completion and repeated
idle/RTC USB behavior remain device gates. No stable promotion is authorized.
