# SM7675 native display candidate

Recorded on 15 October 2026. This directory contains a Linux 7.2.9/7.2.10 source
candidate for the Xiaomi Pad 7 O82 panel and SM7675 primary display pipeline.
It is separate from the firmware framebuffer used by the normal boot recipe.
**Native display reaches Fedora, SSH and active scanout, but visible output remains unavailable.**

The DPU catalog, panel, DISPCC, HLOS interconnect, DSI PHY and SMMU handoff
objects compile for AArch64. The source contains seven fixed modes: 30, 48, 50,
60, 90, 120 and 144 Hz. Lower rates retain their OEM timing-group clock and
extend vertical front porch using the downstream calculation. This does not
advertise continuous VRR or seamless rate switching. The first native test
must use the 60 Hz mode from the reviewed 120 Hz timing group.

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

The next isolated diagnostic reads the OEM-supported one-byte build ID at
0xDA and standard DCS power mode at0x0A after ON/PPS and before video. Each
physical link is read independently in HS; the device's original mode flags
are restored after every read. Results are advisory raw values, short replies
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
panel acceptance. The next isolated candidate adds `MIPI_DSI_CLOCK_NON_CONTINUOUS`
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
