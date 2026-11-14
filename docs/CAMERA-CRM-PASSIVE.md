# Uke firmware-managed camera clocks

14 November 2026. The running `7.3.3-26-unstable` kernel reports CAMCC
`fault -95`, `firmware-enabled-refused`, phase `crm-admission` and last
gate `0x13308` / readback `1`. Neither a media controller nor a fitted sensor
subdevice is present. The two video devices belong to Iris codecs.

The exact Xiaomi Cliffs descriptor and the pinned OnePlus SM7675 descriptor
agree on 38 firmware-managed objects: five PLLs, their five even dividers,
seven PERF RCGs, one BW RCG and twenty branches. The existing eight-client
adapter covers the RCGs. The passive adapter adds the other thirty objects,
validates the full topology before snapshotting powered registers, and does
not change catalog callbacks until every snapshot and RCG preflight succeeds.
Read errors propagate instead of publishing partial state. Unknown divider
encodings refuse rather than silently assuming division by one.

PLL/divider callbacks cannot program their firmware-owned parents. Branch
rate requests still propagate to the RCG voter. Native prepare, enable,
disable, set-rate and initialization writes are excluded from the passive
objects. Both native PLL configuration passes and the native boot-hold path
skip attached passive objects. Observational callbacks read only while the
permanent controller is powered and otherwise retain their last checked
observation without waking it. Active read faults latch the existing owner
fault. PLL arithmetic retains the OEM upward kHz rounding and admitted supply
ceiling; the parent LUT adapter remains a separate required integration.

The source qualifier retains the complete signed full26 source preparation
and all parent assets. It compares all thirty names, classes and offsets with
the independent hash-pinned OEM descriptor, exercises actual attachment and
fault paths with GCC/Clang and sanitizers, retains native handoff/refusal
controls and builds the real complete provider and forced all38 adapter as
AArch64 objects with `-Werror`. Its text receipt is not a target runtime.

This does not activate CRM. The unchanged firmware guard still refuses it.
Permanent transport/IRQ binding, actual ROM parent resolution, inherited
AP SWDRV0 votes and their sync withdrawal must precede activation and provider
publication. Front native bus/sensor/CAMSS graph admission and real RAW frame
completion follow that boundary. Both full cameras, private read-only EEPROM
calibration consumption and rear focus/parking remain unqualified.

The target has `CONFIG_LIVEPATCH` disabled, forced module signatures and
integrity lockdown. `CONFIG_OF_OVERLAY=y` alone provides no ready configfs
overlay interface. No live code, CRM-disable, EEPROM or lens write was made.
Candidate delivery remains cumulative unstable COPR builds and DNF.

Sources: MiCode `5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
`drivers/clk/qcom/{camcc-cliffs.c,clk-alpha-pll.c,clk-branch.c}`,
GPL-2.0-only with Qualcomm/Linux Foundation attribution; OnePlus
`fc892483f1d61f245924681eb5abd563564d9cba`, same CAMCC file, byte-identical.
The bounded 14 November upstream queue search also found the 14 October
SM8650 clk-DVFS DNM RFC discussion, which explicitly leaves CRM support open;
its different SoC and rail/DVFS proposal is not an active-Uke firmware handoff.
The existing CESTA SM8750 display proposal is likewise architectural evidence.
No applicable ready-made SM7675 firmware CRM replacement was established by
this search. Exact inputs are recorded in the source manifest and the retained
`camera-crm-source-review-20261105.json`.

The first qualifier,11327237/native111, failed during the retained source
preparation after257s. Its extracted source phase omitted the earlier prepared
dual-light fixture dependency; passive tests and AArch64 objects were not
reached. Native112 retains the complete55-line original full26 build-source
prefix, including config closure, the prepared fixture and original source
phase ordering. No production feature or required parent check is removed.

An additional review correction pins observational register reads with
`pm_runtime_get_if_in_use()`. A plain active-state check could race the last
owner's put and runtime suspend. The callback now acquires an existing-use
reference without waking idle hardware, releases it with `put_noidle()` after
a successful snapshot, and retains it on a powered read fault in quarantine.
The actual fixture covers last-owner withdrawal and refusal of a fourth
semantic mutant that drops the observation's pin before its read. Neither
source revision activates CRM on the target.
