# Cumulative audio and system-sleep followup

5 November2026, POCO Pad X1 / SM7675, kernel7.3.1-12206-unstable from
COPR11267328/source424caffa. This is source work pending COPR and hardware
qualification. It extends that entire hash-pinned source RPM; it does not
reconstruct an earlier sparse branch.

The DSP returns24/AR_EDUPLICATE during GRAPH_OPEN, followed by speaker failure.
The failed graph ID is not in the existing log, so the original duplicate's
origin is still unknown. The current error path calls provider-wide FS19xx
shutdown for every graph; that erases speaker provisioning and permanently
returns ENODEV. Scope cleanup to the failed graph and report its identity.
Speaker graph40 still mutes, erases calibration and enters Fault on failure.
Every failed graph ID remains quarantined. Successful graphs and provider
removal retain their existing lifetime rules. The exact protected223 RX/VI,
IMCL, per-unit provisioning and all amplifier admission gates remain intact.
This fixes erroneous cross-graph cleanup; it does not yet prove audible sound
or resolve an independent duplicate in graph40.

A requested RTC/s2idle trial aborts in CAMCC system suspend with-EIO. A separate
nearby suspend-abort sequence is followed by xHCI removal and all dock devices
disconnecting. This correlation does not yet prove the USB role-change cause.
The desktop timeout preferences were restored byte-for-byte and the RTC alarm
was cleared. The explicit trial never reached actual RTC-driven resume.

CAMCC deliberately retains its power/ownership when firmware CRM is refused
at crm-admission/-EOPNOTSUPP before publication. Generic forced runtime suspend
then rejects that quarantine, preventing system sleep. The proposed dedicated
system callbacks retain the already held resources across s2idle only in this
exact unpublished state: all three proxy/power votes, interface clock, probe
reference and no uncertain rails, rollback error, registered clocks, published
provider or child consumers. The PM core adds one prepare reference, so the
expected usage count is two. No runtime-suspended state is fabricated and no
CRM, clock, regulator or MMIO operation is introduced. Deep sleep, other faults
and partial publication retain the existing refusal. This holds extra power
while the camera CRM implementation remains incomplete; it does not enable
either camera or withdraw the camera admission guard.

The exact Uke native provider is the relevant implementation; OEM Android and
same-SoC camera implementations do not have this project's permanent refusal
state. Their runtime-PM callbacks cannot be substituted without changing its
ownership model. Linux7.3.1 `drivers/base/power/main.c`, SHA256
`a704473ddbabfc19fea20d24944b12e6e1889a230d7a76b66ef92bce1cc77eb4`, confirms
`device_prepare()` acquires the extra runtime reference. Linux system-sleep and
runtime-PM documentation distinguish s2idle from state-losing deep sleep and
require runtime status to match hardware. Source is GPL-2.0; the AudioReach
error-code definition is BSD-3-Clause from Qualcomm's engine
b38cb85a1a2543aa28aa1b27f4c380cafa5024bb. Existing attribution is retained.

COPR fixtures execute actual failed-OPEN/release functions with an original
failure control, and actual CAMCC system callbacks with22 refusal conditions,
repeat cycles, deep-sleep rejection and changed-state resume. Real q6apm and
CAMCC objects must compile before a full kernel. Physical audio, true RTC sleep,
external-monitor/USB continuity and repeated operation remain acceptance work.
Automatic staging and rollback preferences remain separately owned. An actual
alternating A/B updater change and recovery-artifact admission are required
before the next device installation; this kernel source does not supply them.

Source preparation11267957 failed before compilation: GNU patch with fuzz0
rejected shortened context in the new CAMCC delta. The corrected delta uses
complete generated context; no kernel package or device change came from that
attempt. The following check uses a fresh receipt release.
The following11267971 source preparation passed the patch admission and inherited
preparation, then refused the new synthetic fixture because its APM model lacked
the cumulative provider-removal field. The fixture now retains and tests that
actual guard. Production code and earlier removal admission remain unchanged.

Source/native check11267990, commit a51b48ae, passed the retained preparation,
actual audio/CAMCC fixtures and changed native objects. Its independently
verified normal-key signed text receipt is SHA256
`b236f10048dd52ebb154d727034d86b51838e4d0b3efc90837fc5b53240c7354`.
No Image or physical audio/sleep acceptance is inferred.

Before the following freeze, qualified issue14 contribution9ea9a0c8 is carried
into both recipes: newly generated Android v4 headers use os_version0 while
historical inspection remains compatible. Its codec/contract hashes match the
retained signed11267985 receipt, independently verified by this coordinator.
That completed fixture was retired after evidence preservation. The local
contribution is republished with the cumulative source; no additional branch
or partial kernel is built. No AVB footer, vbmeta or firmware change accompanies
this isolated header delta. Re-run the combined source check before reserving
the complete full kernel. Own-device and reporter Pad7 boot results are separate.
