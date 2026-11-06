# Protected audio GPR response client data

6 November 2026. Full 12214 boots on POCO Pad X1 and registers the permanent
audio supplier and three ALSA PCMs. The supplier and frontend share the same
translated DMA group. One-second direct ALSA DisplayPort playback of zero PCM
and microphone capture to a discard sink both complete. These transfers do not
establish audible output or useful microphone samples. The first protected
speaker prepare returns EPROTO; subsequent graph-open errors follow its
quarantine. Speakers remain muted at the existing gain ceiling of 223.

The backend currently rejects every nonzero bit of Linux's 16-bit `reserved`
member in the second GPR header word. The GPR protocol instead assigns its low
four bits to client data. Valid ordinary APM responses on this device contain
values from zero through six in that field. The failed protected MAP response
was not traced, so this establishes a concrete compatibility defect rather
than proof that it is the only speaker fault.

The new patch accepts bits 16–19 of the domain word and still rejects bits
20–31. Domain, port, token, version, header and packet size, opcode, status and
mapping-handle checks remain. The 5360-byte tuning record, DMA allocation,
mapping lifetime, erasure, uncertain-transaction quarantine, protection and
amplifier controls are unchanged. No firmware or calibration value is added.

## Source comparison and attribution

The pinned donor inventory and shared donor policy were consulted. Exact Uke
and same-SoC comparisons remain documented in PROTECTED-CONFIG-SMMU.md and
the preceding OOB records; their board resources and tuning are not changed.
No board-specific alternative GPR header contract was established. This change
uses the common AudioReach protocol rather than another board's hardware data.

[AudioReach's GPR design](https://audioreach.github.io/design/gpr_design.html)
defines four usable client-data bits and requires the other reserved bits to
be zero. AudioReach/audioreach-graphservices commit
558ddfc2c87019496957855c209dd5ece4f6aceb, `gpr/api/gpr_packet.h`, explicitly
defines `GPR_PKT_RESERVED_MASK` as 0xFFF00000. That Qualcomm/AudioReach header
is BSD-3-Clause; it remains an unchanged reference, with no implementation
copied. Current upstream Linux f66469d9905b39d2c260a15d7d6db450f4db67c1,
`include/linux/soc/qcom/apr.h` and `drivers/soc/qcom/apr.c` (GPL-2.0), uses
the same wire layout, names the upper 16 bits `reserved`, and copies the
received header without this additional all-zero restriction. No queued
correction for this project-owned backend was established.

## Required qualification

New GCC/Clang normal and ASan/UBSan tests execute the actual patched backend
with the actual kernel GPR declarations and an independent wire encoder.
All 16 client-data values run the existing fault and allocation cases. Each
of the 12 genuinely reserved bits must refuse. The original backend and
mutants that accept reserved bits or reject valid client data must fail
assertions. Exact pre/post hashes and inverse comparison restrict the delta.
Historical source, tests and manifests remain unchanged and run before this
new layer. Actual cumulative AArch64 backend and APM composite objects must
pass; a subsequent full build also requires linked Image checks.

Source check 29 precedes any full 12215 reservation. Matching physical boot,
protected prepare and safe playback, actual microphone samples, audible DP,
restart and suspend remain separate device gates. Gray-handover stability,
initial closed-cover state and intermittent USB loss remain open. Automatic
inactive-slot staging and persistent rollback preferences are retained; no
stable promotion or health approval is granted.
