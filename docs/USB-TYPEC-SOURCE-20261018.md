# USB-C and DisplayPort source candidate

Date: **18 October 2026**. Target: Xiaomi Pad 7 / POCO Pad X1, SM7675.
Environment: source preparation on Fedora. No test, compiler, package builder,
emulator, device command or publication was run for this candidate.

The source starts at kernel `99c20362d7be332bc8f33c58424b7c014fffd120`.
The handoff used `43e4036e8e23a1dd81985b01178650698e89e74b`; intervening battery,
ADC, input and source-package changes are retained. Uncommitted battery/VRR
worktrees are separate and have not been overwritten or silently integrated.
Both 7.2.9 and 7.2.10 receive version-specific patches and updated source locks.
The source lock is not a built or installed boot tuple.

| Source | Resulting behavior | Remaining validation |
|---|---|---|
| 0052 UCSI GLINK | Exact read/write packet bounds, little-endian return-code decoding, immediate firmware errors, pending-opcode checks, timeout quarantine, service generation and bounded teardown | KUnit parser, real callback/workqueue/PDR races and firmware ABI |
| 0053 PAN | Bounded per-port event queue, IRQ-bearing events retained, explicit pin validation and VDO bitmask conversion, mux/retimer error propagation, stale-generation HPD suppression and teardown | Wire ACK shape/drain, queue races, actual QMP application and Uke HPD IRQ delivery |
| 0054 MSM DP | Uke source link rate cannot exceed OEM HBR2 ceiling | Actual controller/PHY graph, AUX, link training, mode validation and sink output |
| 0055 PM7550BA | Exact normal Uke host tuning source, 19.2 MHz forcing, device-return reconciliation and error cleanup | Controller/eUSB2/WCD/VBUS chain still blocks host admission |
| 0056 Qualcomm DWC3 | Reapply the explicit USB2 UTMI selection after clock/interconnect restoration | Uke runtime/system suspend and non-Uke regression scope |
| 0057 Uke QMP | Map all 167 normal OEM USB tuning writes, preserve distinct A/B lane values and use the 4nm-v1.1/HBR2 DP source profile | Provider graph, supply/load/reset admission, complete patch/build and both physical orientations |
| 0058 MSM DP controller | Add the explicit SM7675 controller match and binding | AUX/HPD/connector graph, independent modeset and visible external image |
| 0059 WCD observation | Cache the OEM CHIP_ID1 revision after existing peripheral initialization and expose a read-only attribute | Actual installed chip/firmware profile; the observation does not enable host/AUX/audio routing |
| Native display sources | Describe DP0 at DPU-relative 0x34000 and add exact OEM DPTX0 voltage votes | Final DP clock parents and endpoints; the normal display overlay still excludes DP |
| Configuration | UAS and explicit UAC2/HID/UVC configfs functions are requested | Kconfig resolution, endpoint/resources, userspace producers and permissions |

The UCSI decoder fixtures compile against the same helper as the driver; they
cover truncated/oversized frames, v1/v2 buffers and asymmetric nonzero errors.
The UTMI harness uses the actual driver functions. Neither was executed.
KUnit is optional and is not enabled in the normal tablet profile.

## Ownership and protocol limits

Firmware owns CC/PD and the electrically controlled source/sink path. BATT,
UCSI and PAN are separate clients on one transport. No second TCPM, VBUS GPIO,
raw PMIC writer, source PDO, charger limit or factory override is introduced.
The existing battery-only endpoint remains battery-only. The fixed USB2
peripheral overlay and its DWC3/eUSB2 host gates remain the rescue profile.

GLINK SET/ACK success is not physical completion. PAN ACK consumes an event;
it does not certify the mux, AUX, trained DP link or visible image. QMP can defer
a requested change while DP is active. A successful provider return therefore
remains insufficient for the policy planner to mark an operation verified.

These protocols lack wire transaction IDs. Timeout, send ambiguity, event queue
overflow or loss of an established service quarantines the affected instance.
There is no automatic software retry/reset that pretends to drain old replies.
A documented firmware drain/epoch contract is needed before automatic recovery
can replace the conservative new-boot boundary. Driver reprobe in the same
firmware session is not qualified resynchronization. Arbitrary duplicate replies
after successful commands also remain a wire-contract validation requirement.

## Source gaps that remain

Full host, Gen1, DP, passive analog audio and combined dock support are **not
source-complete**. The following are concrete missing integration inputs/work:

1. Resolve effective WCD status/binding/revision and USB/DP/audio route ownership.
   A phandle and the minimal peripheral switch driver do not establish a general
   host/AUX/audio implementation. Do not extend its protection/FSM overrides.
2. Define the actual Uke firmware source profile, VBUS/sink controls, supported
   swaps, fault ownership and safe source-off/readback. The bounded SDP ICL path
   is not a PD or reverse-charge API.
3. Qualify the new exact-OEM QMP profile and adapt its clock/reset/regulator and
   orientation/mux graph. Palawan's pinned DTS names a QMP compatible without a
   corresponding driver match at that pin; its board graph is not a working Uke profile.
4. Connect the DP controller/AUX/PHY/DPU endpoints and DISPCC parent clocks. The native
   Uke display overlay disables `sde_dp` and uses null DP clock inputs. Preserve
   internal O82 DSI/DSC/DFPS and complete the DP audio codec/ELD path separately.
5. Complete the firmware-driven role/gadget/active-I/O coordinator, effective
   charging integration, policy controls and persisted sharing authorization.
   The accompanying C++ observer/planner does not apply these hardware actions.
6. Connect analog jack/microphone/bias and SBU arbitration to the actual codec;
   deliver selected MTP/ADB/UAC/UVC userspace producers before exposing functions.

No unqualified full-port DT overlay is offered. The existing ABL transformation
still removes OEM role/extcon/extended-IRQ properties for its peripheral profile.
Changing only `dr_mode` would fail the controller gate and would not complete the
graph. A future full profile must preserve and validate its final transformed
graph independently of the frozen rescue fixtures.

The Peridot UTMI change is attributed to Yassin Rezai,
[`0ca0f54453cf83502e868faae8a9aa394dbb102d`](https://github.com/redzrush101/linux/commit/0ca0f54453cf83502e868faae8a9aa394dbb102d),
GPL-2.0-only. It supplies shared glue-driver lifecycle reasoning, not Uke board
tuning or physical Uke suspend evidence. OEM source pins and the complete
requirement/test/gate inventory are in `manifests/usb-typec-20261018.json`.
All new test records remain `NOT_RUN`; G0-G10 remain `NOT_EVALUATED`.

## Cached collection follow-up

The coordinator found that power-supply sysfs reads issue firmware GETs on the
old provider. The host capture helper now reads only Type-C/role/UDC, cached WCD
revision, remoteproc identity and the effective FDT. It invokes no observer or
power-supply getter. The matching USB observer delegates power reads to the
charging owner. Automatic ACM requires an actual device-role provider and
Type-C partner; its former SDP/CDP polling fallback is removed. The fixed-FDT
producer retains guarded legacy rescue ACM until that graph is admitted.
Transport diagnostics and model-attestation files are not cached USB attachment
APIs. The coordinator's earlier host PASS applies to frozen 2.1; this follow-up
requires its own rerun and does not change the full-port source-incomplete status.
