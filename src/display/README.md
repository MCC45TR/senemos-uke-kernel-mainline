# SM7675 native display candidate

Recorded on 15 October 2026. This directory contains a Linux 7.2.9/7.2.10 source
candidate for the Xiaomi Pad 7 O82 panel and SM7675 primary display pipeline.
It is separate from the firmware framebuffer used by the normal boot recipe.
**Native display trials reached Fedora and SSH but have not produced scanout.**

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

The host tests execute the real panel lifecycle and clock functions. They cover
both variants, all seven mode timings, every command-transfer failure, short
writes, supply/GPIO failures, reverse-order cleanup, failed-disable retry and
invalid mode state. The decoder rejects malformed/truncated DT and packet
inputs without emitting a partial header. These are host results.

On/off commands retain the OEM LP state; timing-switch video commands use HS.
The lifecycle test checks both states separately for each timing group.

Recovery on the connected tablet selects O82 42_02_0b. This identifies the
observed unit; it does not remove variant selection for other tablets.
Before native activation, finish binding checks, review display SMMU/VBIF
drain/reset behavior, compare DSC PPS and PHY
timings, and verify the clock/bias power lifecycle on Uke. The common OEM
bit-clock override needs reconciliation for the 90/144 Hz groups; derived DRM
mode arithmetic alone does not validate their physical link rates. Preserve
the firmware framebuffer boot image and Android return route for these tests.
