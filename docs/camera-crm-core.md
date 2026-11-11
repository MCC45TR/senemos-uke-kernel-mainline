# Cliffs camera CRM vote core

The 5 November 2026 implementation separates AP SWDRV0 packet planning from
the future powered MMIO/IRQ transport. The running 7.3.1-12204-unstable reaches
the active-firmware CRM admission boundary and returns -EOPNOTSUPP. This core
does not change that guard, publish clocks or enable a sensor.

Register definitions follow the exact Xiaomi Uke CRM and TCS sources listed
in `manifests/camera-crm-core-20261105.json`. Their Qualcomm and Linux Foundation
attribution is retained in the GPL-2.0-only header. The broader OEM, same-SoC,
upstream and active CESTA queue comparison is recorded separately in
`manifests/camera-crm-source-review-20261105.json`.

Only PERF VCDs 0,1,2,3,4,6,7 and bandwidth node0 are admitted. The reviewed
CAMCC descriptor does not map VCD5; this is not a global reservation claim.
Bandwidth node count is decoded from CFG2, separately from CFG1 bandwidth VCD
count. Register banks are bounded so unsupported counts cannot alias adjacent
power-state or IRQ banks. Actual firmware version and counts remain unmeasured.

All three packets are validated before the transport callback runs. ACTIVE
requires acknowledged completion; SLEEP and WAKE store future votes. The
transport must retain the power reference and serialize transactions, request
the owned IRQ before enabling it, and handle bounded waits and late IRQs.
The first callback failure stops the sequence, invalidates confirmation and
poisons further attempts. Successful confirmation means one acknowledged
ACTIVE vote and two accepted stored writes, not three observed hardware states.
No automatic rollback or retry is inferred after partial application.

The COPR-only contract compiles the same header as C and C++, compares offsets
with extracted OEM arrays and `crm_get_offset()`, and checks BCM words against
the original TCS macro. It enumerates capability fields and injects errors at
each power state. An independently extracted `clk_rcg2_vote_perf_level()` is
the negative control: its early error is overwritten by later success. This
is a source finding, not the cause of the current intentional CRM refusal.

The core has no register access, IRQ ownership, LUT parsing or CCF integration.
Those remain prerequisites for a native object/full cumulative kernel check
and DNF delivery. Both fitted cameras, private EEPROM consumption, rear focus,
full processed modes and repeated-use/recovery acceptance remain unqualified.
