# Healthy idle during protected speaker shutdown

7 November 2026, POCO Pad X1, full12217/COPR11282652. Internal speaker sound is
confirmed on the device, but repeated use is not accepted. A bounded diagnostic
captures the actual protected graph40 STOP: all four DAC mute notifications
complete, DSP STOP returns status0, and the stopped callback begins gate0.
Another amplifier worker then runs before its sequential power-off notification
and treats the normal non-running state as a protection fault. This latches
Fault even though the DSP acknowledged STOP. An earlier device timeout remains
a separate observation; this diagnostic does not prove every failure identical.

The correction classifies output faults under the same existing spinlock that
publishes gate mode. Healthy mode0 means stop hardware without latching a new
fault. Faulted guards and active/prepared states retain fault publication and
deferred physical shutdown. Classification and fault publication are atomic;
separate unlocked idle checks would leave another transition race. The codec
still resets hardware on either outcome. It never unmutes idle output, extends
a deadline, changes gain223, replaces private calibration or bypasses a real
health error. Existing caller error behavior and VI-until-STOP ordering stay.

The actual cumulative codec worker, notifier, gate, STOP caller and new locked
fault callback are exercised with independent I2C/DSP/work providers. Four
compiler/sanitizer modes include the retained40 STOP cases, all15 combinations
of pending workers during sequential off,15 healthy-idle worker combinations,
three faulted guard modes and the original explicit fault path. The exact17
worker must fail the same interleaving assertion. Refusing all healthy idle and
hiding real faults must each fail with both compilers. Whole-source inverse
checks, strict source refusals and actual AArch64 exported/imported calls are
required. No compilation runs on the tablet.

The pinned donor inventory and shared policy remain applicable. Exact Uke OEM
FourSemi sources at MiCode/vendor_qcom_opensource_audio-kernel
8eb0eccbc4027ae4a4987e4bced03a4381039714 separate DAC mute and hardware stop;
source files have Fourier copyright but no file-level GPL declaration, while
fsm_i2c.c declares MODULE_LICENSE("GPL"). The same-SoC OnePlus audio tree at
1138e00fee63582a0cc6a53af3286621786827b7 does not implement this native guard.
Linux7.3.1 at79a907609d53d5cd645b42c11550d295d43abf99 and current upstream
q6apm.c atd48723711bae9b8cdc56719c448ba42fef28cbee provide lifecycle comparison,
not this project-specific worker fix. Relevant23 October WSA884x protection
RFCs and8 October q6apm failed-STOP caller RFC address related VI/caller lifetime,
not the observed sequential-notifier race. See PROTECTED-STOP-DRAIN.md for exact
paths, licensing and attribution. No donor code or tuning is transplanted.
New project code is GPL-2.0-only.

A separate boot probe race can omit HiFi before private calibration is ready;
one session-manager rescan restores the already packaged profiles. That race
and useful repeated sound remain open. A discarded diagnostic that only reached
auto_null is not speaker evidence. The real test requires the explicit existing
Speaker node and preserves global audio defaults. VRR capability exposure is an
additional requested workstream; this audio delta changes no display behavior.
Source/native checks do not establish transducer limiting or acoustic safety.
