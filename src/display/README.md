# SM7675 native display candidate

Recorded on 16 October 2026. This directory contains a Linux 7.2.9/7.2.10 source
candidate for the Xiaomi Pad 7 O82 panel and SM7675 primary display pipeline.
It is separate from the firmware framebuffer used by the normal boot recipe.
**Native display reaches Fedora, SSH and active scanout, but visible output remains unavailable.**

The 16 October native30 trial matched the working OEM LM and INTF signatures
for identical grey and two-half SMPTE inputs, while its panel remained blank.
Patch `0021` adds a default-off DSI MDP MISR diagnostic for the exact Uke
DSI 2.8, four-lane D-PHY 3200×2136/120 Hz profile. A root-only debugfs write
of 1–8 to `uke-dsi0-mdp-misr` or `uke-dsi1-mdp-misr` captures bounded samples,
then restores the admitted disabled configuration. Reads return only that
capture, including raw status and errors; they do not initiate measurements.
This follows MiCode display revision `44275c404a67`, not a panel test-pattern
generator. It changes no panel packets, clocks or mode. A content change is
still needed to exclude stale signatures; neither a checksum nor a successful
build establishes visible output or valid wire signaling.

Patch `0022` follows the same MiCode revision's video-command scheduler for the
measured O82 120 Hz timing group. Both idle controllers are validated before
arming line 2285; completion clears scheduling and restores DMA roles. Other
timing groups keep their previous command policy. Trigger bit12 is preserved.
A stuck abort retains the existing held-reset quarantine and requires reboot.
Host fixtures cover admission, fallback, paired completion and both timeout
paths; physical scheduling and visible output still require a separate test.

Patch `0023` and the isolated 120 Hz panel profile preserve OEM grouping of the
four HS TP-FPS commands. A synchronous private API packs one 32-byte DMA group,
sets LAST only on the final packet and reuses paired completion and abort
handling. No state accumulates across independent transfers. Other panel
profiles retain serialization; changed group metadata or an API error refuses
the first-frame update. The panel module imports the MSM provider symbol.
Host tests cover packet bytes, refusal, timeout and provider reachability;
visible output remains unverified.

Patch `0024` preserves OEM LP ON grouping in the isolated PB 120 Hz profile:
108 unchanged commands form eight synchronous chunks, 884 padded bytes in
total. The OEM size rule includes the nonterminal packet that crosses 240
bytes before ending that chunk. Both video engines must remain off. Ordinary
bridge disable/re-enable now preserves a blocked DMA quarantine before PHY or
power changes; arbitrary unbind or KMS destruction remains outside the trial.
ON delays, OFF, PPS, HS TP-FPS and other modes retain their existing contents
and order. Native35 completed ON and HS groups in a physical test, but held
SMPTE remained invisible.

Patch `0025` programs the exact Uke OEM HS video timer, including its resolution,
for the isolated O82-42 120 Hz profile on DSI 2.8. Other modes and panels retain
their existing timer state. Source and host checks do not establish that the
previous timer caused the blank display; visible output remains a separate gate.

The DPU catalog, panel, DISPCC, HLOS interconnect, DSI PHY and SMMU handoff
objects compile for AArch64. The source contains seven fixed modes: 30, 48, 50,
60, 90, 120 and 144 Hz. Lower rates retain their OEM timing-group clock and
extend vertical front porch using the downstream calculation. This does not
advertise continuous VRR or seamless rate switching. The normal native overlay
retains the 60 Hz mode from the reviewed 120 Hz timing group.

`o82-data.cpp` is a host-only C++ decoder. `o82-oem.dts` compiles the four pinned
OEM panel files into a minimal source DT; `o82-data.h` contains only the two
panel variants' commands and derived timings. It contains no device identity
or calibration data. The decoder retains packet types, lengths, flags and
settle delays. Both installed-firmware-derived and OEM-source inputs produce
the same header. The driver selects a variant from its exact compatible;
it does not assume that every Uke has the same panel.

The existing paired KTZ8866 driver supplies the OEM nonlinear brightness curve.
Native panel power/reset lifecycle is separate from brightness. Supply loads,
voltages and reset sequencing come from Uke evidence. Probe preserves reset
direction and does not enable the panel. The native graph must reuse this
paired backlight rather than register another writer for the same chips.

## Source provenance

- Xiaomi display DT, revision `4a3e1c391130237c5e8c2b250d1c94f3e25b9b11`:
  O82 36_02_0a, O82 42_02_0b and their QCOM/MI common includes, GPL-2.0-only.
- Xiaomi kernel, revision `5712080a4b0c0b1a879e6d145c601c649ddaddfd`:
  Cliffs display clock voltage tables and HLOS interconnect routes,
  GPL-2.0-only. Verify this identity against the local acquisition manifest
  before regenerating a source bundle.
- [linuxgamer/uke-fedora](https://github.com/linuxgamer/uke-fedora), revision
  `cf4f9317a7fef3e9bdddc36bedcb257fa51b0994`: O82 lifecycle, scoped DPU catalog,
  clock votes and display DMA/SMR handoff, GPL-2.0-only. The donor's scripts are
  not build inputs and are not executed.
- [Palawan Linux](https://codeberg.org/palawan-mainline/linux), revision
  `0d9f7fdf720ae9f4ecfbee4fadaf1e3b5c442e95`: shared SM7675 display resources
  and Lamma GPU operating points. Board GPIOs and memory addresses are not
  transferred from adjacent devices.

`patches/display/7.2.10/0001-native-display-providers.patch` registers the isolated
providers on the normal 40-patch prepared source. The source files in this
directory supply its included assets. It does not modify the normal release
series or activate native DT nodes. Removed 6.12-only feature fields follow
the 7.2.10 catalog API; DPU instances, XINs and offsets remain explicit.

`prepare-source.sh` stages these files only in a separate prepared 7.2.9 or 7.2.10
source tree, checks the patch before modification and refuses a second install.
`sm7675-uke-native-display.dtso` is an offline dual-DSI graph. Its panel variant
must be selected explicitly as 36 or 42; neither is assumed. Graph tests retain
RAM, reserved-memory and the firmware SMMU handoff rules, and reuse the existing
paired backlight. This overlay is not embedded in the normal boot image.

The isolated native entry now recovers the existing OEM bias-regulator symbols
that ABL omits. It retains the actual provider nodes, bootloader-selected panel,
RAM and reserved memory. The graph uses the OEM L4B controller and L2B PHY
supplies; the bonded DSI1 byte/pixel clocks use the master PHY0 PLL. Host checks
compare the supply phandles with the captured OEM graph and reject missing
providers. No adjacent board regulator or GPIO values are substituted.

The first native boot reached the Fedora root, USB console and Wi-Fi SSH, but
did not create a display connector. DISPCC was waiting for its OEM MMCX rail;
the retained RPMh admission list omitted `mmcx.lvl`. Panel IO resource `ldob8`
also needed admission. The isolated supply patch adds these exact resources
and retains command-DB address/type/level validation and the OEM CX parent
dependency. It does not substitute a dummy regulator or fixed voltage.

The second physical trial passed the supply dependency, but display handoff
returned `-EACCES`. The core stayed reset and the screen was black. A diagnostic
trial established that the failure occurred before register access: Apps SMMU
has no runtime power domain and stays on, while the draft called runtime resume
unconditionally. The corrected candidate follows upstream SMMU's conditional
get/put and autosuspend handling. It also preserves SID/mask when clearing SMR validity, as in
the exact Uke OEM SID-release path. It checks identity before each write and
retains refusal diagnostics, secure-stream isolation and context reservations.
Host fixtures cover ownership changes and rejected writes; physical acceptance
remains open.

With the conditional SMMU power handling, the fifth trial registered both DSI
controllers, the SM7675 DPU, a connected DRM DSI connector and `msm-kmsdrmfb`.
It still produced no visible image: panel rails/reset were off and repeated
FIFO-class DSI interrupts occurred. The next diagnostic candidate records the
exact panel preparation failure and raw controller error registers. Connector
registration alone does not establish panel power, scanout or a working mode.

`prepare-native-abl-source.sh` applies this entry only to a separate tree that
already contains the normal ABL adaptation and native providers. Its initial
bring-up graph sets `xiaomi,initial-60hz-only`, so a saved desktop setting cannot
select an unmeasured high mode. The complete seven-mode source table remains;
the limitation is removed after physical rate qualification. Standard DRM
connector modes make accepted fixed rates visible to KDE and other desktops.
OEM VFP-based dynamic FPS does not alone establish DRM adaptive sync. Neither
the prepared DPU nor DSI implementation currently provides a qualified VRR
path; no `vrr_capable` property is fabricated.

## Validation and remaining work

The isolated O82 PHY binding uses the compatible pair
`"xiaomi,uke-o82-dsi-phy-4nm", "qcom,sm7675-dsi-phy-4nm"` on both links.
It has the existing SM7675 resources and supplies; it adds no raw register or
userspace timing interface. Both exact OEM O82 variants have the same 14-byte
PHY timing override in `uke-sde-display.dtsi` at revision
`4a3e1c391130237c5e8c2b250d1c94f3e25b9b11`. The candidate applies those named
timing fields through the existing PHY writer only on Uke/SM7675, D-PHY id0/1,
and lane clocks 1,189,187,000 through 1,189,191,000 Hz. This narrow window
contains the current 60 Hz arithmetic result 1,189,188,000 Hz and the OEM
override 1,189,190,000 Hz with 1 kHz boundary margin. Other groups remain
refused until their clock and physical mode checks pass.

The active native12 capture differed from that OEM array in six fields. The
generic calculator remains in place for validation and clock-division state;
other PHY compatibles keep its original timings. Existing shared pre/post
propagation to the host is retained. Android parses host pre/post separately,
so matching the PHY array does not imply every host register matches Android.
Run `bash tests/o82-phy-timing-contract.sh PREPARED_KERNEL KERNEL_OBJECTS` to
exercise the actual calculator, scoped helper, PHY writer and copied host
timings. This is a source candidate; visible native output remains unqualified.

The native15 diagnostic reads the OEM-supported one-byte build ID at
0xDA and standard DCS power mode at0x0A after ON/PPS and before video. Each
physical link was read independently in HS; the device's original mode flags
were restored after every read. Results are advisory raw values, short replies
or errors, with no invented expected power byte and no new boot rejection.
MSM's bonded DMA trigger now retains read-transaction context for both the
maximum-return-size packet and actual read. Ordinary write broadcast is
unchanged. Each one-byte read uses at most two existing 200ms DMA waits;
failed transport unwinds through the existing host restore path. Run
`tests/dsi-read-transaction-contract.sh` and `tests/o82-readback-contract.sh`
against the prepared source before building this diagnostic. The existing
RGB24 DSI test-pattern generator is not used as evidence for a DSC stream.

Native15 completed all four per-link reads without a DMA timeout, but rejected
each response header. It returned no panel byte; local DMA completion is not
panel acceptance. Native16 added `MIPI_DSI_CLOCK_NON_CONTINUOUS`
to both O82 links. Both exact OEM variants omit forced HS clock, and the reviewed
upstream NT36532 driver also requests non-continuous clock. Timings, DSC,
packet geometry, EOT, initialization commands and PLL state remain unchanged.
`0012-native-dsi-invalid-rx-diagnostics.patch` records the selected link,
decoded four-byte header, raw RDBK words, revision-qualified RDBK control and
timeout status on the existing invalid-response path. It adds rate-limited
logging with existing host accessors; it changes no return value or timeout.
The extended panel/read fixtures test both links, attachment unwind, invalid
headers, old-revision refusal of the control read and transport cleanup.

Host software-reset and bonded PHY-reset precede enable, but the non-continuous
branch does not explicitly clear inherited force-HS bits. Physical acceptance
must therefore verify controller LANE_CTRL bit28 and PHY LANE_CTRL1 bits5/6 are
clear on both links, then check raw readback and visible output. A flag change
alone cannot establish that the live clock policy changed. The active Pad 2
queue's PLL patch `93c97bc8d85d` was reverted upstream by `44784327815b`; it is
not included in this candidate.

Native16 confirmed non-continuous clock on both links and returned primary
DA=0xc3 and power mode=0x9e. Secondary reads produced ACK errors and zero
headers; visible output remained blank. The exact Uke OEM read path addresses
only command-master DSI0. Native17 therefore retained the two advisory
HS reads only on DSI0 and left the secondary untouched. It preserved generic
per-link read support and all write broadcasts. Captured error-worker status4
does not invoke the MDP-underflow reset path, which tests bit0x8; no secondary
reset is claimed. PHY strength and every native16 video/protocol setting remain
unchanged for this separate lifecycle test. The physical native17
trial again returned DA=0xc3 and power mode=0x9e, with no secondary reads or
their ACK errors; the panel remained blank.

The next isolated candidate applies the exact O82 OEM strength pair through
the existing common PHY writer: calibration selection 1 and HSTX strength 0xff.
Both O82 variants specify strength 0xff without deemphasis. Their Uke v5.2
writer selects this pair below 1.5 GHz; the admitted current lane clock is
1,189,188,000 Hz. `0013-native-o82-phy-strength.patch` overrides only these two
locals after generic selection and the existing board, D-PHY, link and clock
admission. Generic PHYs retain their previous values. It changes no voltage,
PLL, timing, lane map, preemphasis, EOT or video setting. The actual-function
PHY fixture checks both links, generic values and rejected writes. A matched
build and physical register, primary-read and visible-output checks remain
required; the blank native17 trial does not establish strength as its cause.

Native18 confirmed the OEM strength pair on both PHYs and valid primary reads,
but the independent test image remained invisible. The next lifecycle change
moves the existing four HS timing-video commands from prepare into panel enable.
Exact OEM O82 post-enable sends them after PPS and video-engine start; the
current DRM chain starts both DSI video hosts before panel enable. ON, PPS,
readback, packet bytes, waits and power handling stay unchanged. The DRM panel
core enables the external backlight only after a successful enable callback;
an error leaves the prepared supplies for ordinary teardown. Host fixtures
execute the actual panel callback and DRM core enable guard, covering both
variants, all seven modes, every failed/short HS transfer and retry.
This corrects an observed source ordering mismatch; visible output and physical
display lifecycle remain unqualified.

Native19 completed the post-video commands and returned valid primary reads,
but neither the desktop nor an independent test image was visible. The next
isolated correction follows the OEM post-link retime sequence: after both
hosts enable their byte, pixel and byte-interface clocks, toggle each PHY's
retime FIFO off/on, then clear CLK_EN_SEL bit4 on both PHYs. The optional PHY
pair operation runs before IRQ enable and panel prepare. It requires both O82
compatibles, Uke/SM7675, D-PHY master0/slave1 topology and the current 60 Hz
lane-clock window above, recalculated from the active host. Rejected pairs
write no PHY registers and unwind both powered hosts. Missing operations or
mismatched PHYs also refuse this O82 route; unrelated panels bypass the call
and retain their previous behavior. The actual manager and PHY fixtures check
ordering, preserved register bits, unsupported-pair refusal
and refusal cleanup. A matched build, live register capture and visible image
remain required. No host timing, DSC, EOT, frequency or panel-command change is
combined with this correction.

On 16 October 2026, native20 on Uke matched the working OEM PHY clock-select
values 0x20/0x24 and returned primary DA=0xc3/power=0x9e, but the desktop and
an independent XR24 test image remained invisible. The next isolated change
sends the OEM LP normal-pixel packets after the four HS timing commands:
type0x15 `FF 10`, then type0x39 `13 00`, with zero explicit waits. They come
from `dsi-panel-o81-o82-dualdsi-dsc-lcd-video-micommon.dtsi` at DT revision
`4a3e1c391130237c5e8c2b250d1c94f3e25b9b11`; display revision
`44275c404a677d9d9e5230fedd1af2ef02fc7b9a` sends them on O82's first positive
backlight update. This candidate sends them before DRM-core backlight admission
and rejects failed or short transfers. It does not reproduce OEM's
first-completed-frame wait or its backlight-before-DCS order, and adds no
runtime zero-brightness hook. Existing HS transfers do not guarantee a completed
frame. The actual panel fixture checks both variants, seven source modes and
transfer/lifecycle failures; matched build and optical validation remain required.

Native21 completed ordinary B-slot startup on Uke on 16 October, returned valid
primary reads and logged no normal-pixel transfer error. The desktop and an
independent XR24 image remained invisible. The next isolated timing candidate,
`0015-native-dpu-video-timing-master.patch`, follows exact OEM display revision
`44275c404a677d9d9e5230fedd1af2ef02fc7b9a`: only the non-slave video encoder
starts its timing engine, while both physical encoders become ENABLED. It is
scoped to the dedicated SM7675 catalog. Both interface setup and modern CTL
flush paths, slave underrun reporting, master-only vblank policy and existing
native disable/cleanup remain intact. Other catalogs and SOLO/MASTER writes
retain their behavior. This changes no panel, DSI, PHY, DSC, fetch or clock data.

The timing patch suppresses an enable write; it does not clear a slave engine
inherited as enabled. The physical test must observe INTF1/INTF2 enable1/0,
with CTL interface-active6, master2 and DSC-active3, before assessing output.
The actual-function host fixture covers those software paths, all initial
states, two lifecycle cycles, frame/commit waits and the inherited-enable
limit. Visible output, idle collapse, suspend and mode-change behavior still
require separate Uke tests.

Native22 ordinary B startup on 16 October confirmed interface enable1/0,
CTL interface-active6, master2 and DSC-active3 on Uke, including independent
XR24 scanout. Both desktop and test image remained invisible. The next isolated
change, `0016-native-o82-host-clock-timing.patch`, separates the OEM host
pre/post counters from the PHY timing cells. The exact OEM panel parser and
controller writer use separate host properties, absent from both selected O82
DTs and zero in the working capture. After all14 PHY bytes are written, the
admitted O82 path exports host pre/post0/0 while retaining PHY cells12/13 at
0x20/0x0f. Its existing board, D-PHY, link and lane-clock admission remains;
generic PHYs retain their calculated host values. The actual-function fixture
checks both links, repeated enable, the unchanged divider flags and existing
paired-retime sequence. This changes no PLL, DSC, master timing, panel packet,
EOT or timeout policy. A matched build and live register/optical checks remain
required; the prior first-frame/backlight ordering limits still apply.

Native23 ordinary B startup on 16 October confirmed host pre/post0/0, unchanged
PHY timing cells and interface enable1/0. Primary panel reads were valid; the
desktop and an independent XR24 image remained invisible. The separate
`sm7675-uke-native-display-120hz.dtso` now permits an isolated comparison with
the working OEM capture's 120 Hz timing. It includes the normal graph and
replaces only its initial-mode property, requires O82-42 at preprocessing and
probe, and publishes one preferred 120 Hz mode. Conflicting profile properties
are rejected before regulator acquisition; any nonmatching prepare mode is
rejected before power or commands. The normal 60 Hz overlay is unchanged.

The exact generated 60/120 timings share timing group0, ON/switch/OFF commands,
128-byte PPS, supplies and pixel clock. Vertical total changes from 4620 to 2310;
the existing compressed clock calculation retains the 1,189,188,000 Hz lane
rate and current PHY admission. No generated panel data, clock parent or DSC
parameter is changed. Host tests cover single-mode enumeration, invalid
profiles, prepare rejection and the existing lifecycle/fault paths. A matched
120 Hz build and Uke register/optical tests remain required; this does not
qualify dynamic refresh, live mode switching or other rates.

SM7675 snapshots separately include DSC_CTL offsets 0x10/0x14 for the two active
encoders, whose earlier dump span omitted them. This extends read-only telemetry;
it does not enable 4HS or assert a mismatch with the working OEM capture's zeros.
`tests/dsc-ctl-snapshot-contract.sh` checks the actual catalog and snapshot
reader/printer bounds, including no access to padded words. Native24 on Uke on
16 October confirmed the exact 120 Hz mode and both control-word pairs at zero,
matching the active OEM capture. The desktop and held XR24 test remained blank.

Native25 on 16 October logged the vblank boundary, checked positive KTZ update
and LP completion, but desktop and held XR24 output remained invisible. The
selected OEM atomic path also starts DPU timing before its four HS commands;
native25 still sent them before kickoff. The same standard DRM vblank work
item now sends those unchanged HS commands before the existing KTZ and LP
operations. This corrects the earlier assumption that DSI VIDEO_ON alone meant
DPU timing was already running. Panel enable returns before MSM kickoff;
disable and unprepare join pending or running work before host or rail teardown.
Schedule refusal, backlight and packet failures are reported and request blanking.
Core enable admission is separate from asynchronous completion. A vblank is not
a panel acknowledgement or proof of this commit's first frame with inherited
running timing; missing events, resume and visible output still need Uke tests.

Native26 on 16 October completed the deferred HS, backlight and LP sequence,
but neither the desktop nor an independent XR24 pattern was visible. A separate
VIG0/VIG1 scaled SMPTE test also produced no visible color bars. The next isolated
Uke trial set the OEM hardware split-flush flag while retaining upstream's two
software submissions. Native27 confirmed the flag on the tablet, but the held
XR24 SMPTE pattern remained invisible. That patch is retained for attribution
and excluded from the active preparation queue.

The next isolated trial restores seven OEM FLL defaults immediately before
starting the stopped master PLL. The exact Uke OEM and same-SoC sources agree
on these values; the active OEM capture differs from the native capture at all
seven fields. The guard requires the admitted O82 D-PHY pair and lane rate.
Invalid scope or a running PLL refuses initialization and balances the acquired
bias references. Rate, voltage, dividers and the existing lock sequence remain
unchanged. Host fixtures cover register order, refusal and error cleanup.
This source-backed difference has not established the cause of the blank image.

Native28 confirmed all seven FLL values, PLL lock and the panel readback on
16 October; the held SMPTE image remained invisible. Controlled SMPTE/tiles/SMPTE
tests produced repeatable, pattern-dependent signatures at both layer mixers
and DPU interfaces. This does not establish valid DSC decoding or DSI delivery.

The next isolated O82 trial stages both command DMA engines before triggering
slave1 and master0, following the exact Uke OEM ordering. Both completions are
required. Reads and other panels retain their existing path. Timeout disables
and resets both engines, then checks idle before command-role restoration.
If reset cannot clear busy, both hosts retain TX storage and refuse further use.
This trial must end and reboot on its first transfer timeout; unbind, reprobe,
module unload and KMS teardown are outside its recovery contract. It is not a
production recovery implementation or a qualified display fix.

Native29 confirmed both command completions on 16 October. The held SMPTE
image remained invisible, with no observed command timeout or underrun. The
next isolated trial submits the shared DPU CTL once, following the OEM route,
while retaining both modern interface masks and both physical encoder counters.
The scoped split flag is cleared only after a completed stop and fresh inactive
status from both interfaces. Patch20 includes this behavior; patch17 remains
excluded. Host fixtures cover repeated frames, transition states and unrelated
topologies. Visible output and the physical stop/re-enable cycle remain unverified.

The host tests execute the real panel lifecycle and clock functions. They cover
both variants, all seven mode timings, every command-transfer failure, short
writes, supply/GPIO failures, reverse-order cleanup, failed-disable retry and
invalid mode state. The decoder rejects malformed/truncated DT and packet
inputs without emitting a partial header. These are host results.

On/off commands retain the OEM LP state; timing-switch video commands use HS.
The lifecycle test checks both states separately for each timing group.

The O82 rate-control parameters follow Xiaomi display revision
`44275c404a677d9d9e5230fedd1af2ef02fc7b9a`: first-line BPG offset 13 and
range-zero maximum QP 8 are applied before upstream RC calculation. The panel
then sends the standard 128-byte PPS over both LP links after initialization.
Each PPS describes 1600 pixels; the shared DPU frame remains 3200 pixels.
Host fixtures execute the selected upstream RC calculator and PPS packer,
compare all payload bytes with the OEM-derived fixture, and reject failed or
short transfers on either link. An isolated DPU correction rounds compressed
active width up like the DSI host and OEM timing conversion. These source and
host checks do not establish visible scanout.

The native panel uses the OEM 30-bit RGB101010 input format. Both the exact
OEM controller and upstream MSM retain that format when the DSC wide bus is
available; using RGB888 would select a different DSI destination format even
with identical DSC clock arithmetic. Physical transport remains under test.

The RGB101010 trial removed the previously observed DSI interrupt storm, but
neither KDE nor an independent DRM test framebuffer produced a visible image.
The native-only source also carries the OEM DSC full-ICH precision capability
for more than 8 bpc. Its register change was observed on Uke without restoring
the image. A separate O82-only bridge candidate preserves host power before
panel preparation and defers video until reset, ON commands and PPS complete.
These changes do not qualify native output or any additional refresh mode.

After preparing the isolated source, run the actual-function host checks:

```sh
bash tests/dsc-precision-contract.sh PREPARED_KERNEL
bash tests/dsi-panel-sequence-contract.sh PREPARED_KERNEL/drivers/gpu/drm/msm/dsi/dsi_manager.c
bash tests/dpu-video-timing-contract.sh PREPARED_KERNEL
```

They test capability/depth refusal, unchanged unrelated register writes,
power/prepare failures, link cleanup and the existing other-panel ordering.
Compile the complete matched Image/modules afterward; host mocks are separate
from the required optical test and reboot/recovery checks.

Recovery on the connected tablet selects O82 42_02_0b. This identifies the
observed unit; it does not remove variant selection for other tablets.
Before native activation, finish binding checks, review display SMMU/VBIF
drain/reset behavior, compare DSC PPS and PHY
timings, and verify the clock/bias power lifecycle on Uke. The common OEM
bit-clock override needs reconciliation for the 90/144 Hz groups; derived DRM
mode arithmetic alone does not validate their physical link rates. Preserve
the firmware framebuffer boot image and Android return route for these tests.
