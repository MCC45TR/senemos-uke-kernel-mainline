# Uke full Type-C and external DisplayPort source profile

18 October 2026. Source environment: joint kernel23 `f429992feb638e7dffc0142ecb77c6b1a86fc16e`, Linux 7.2.10. This successor is a source candidate. No compiler, automated test, tablet write or hardware acceptance was performed by this source task. The VRR coordinator owns the combined build, package and tablet operations.

## Implementation

The native producer selects the versioned `packaging/native/usb-profile` file. `typec-v1` composes a complete firmware/UCSI, USB-role, generic eUSB2 PHY, QMP USB/DP, WCD AUX and native DRM DP graph. `peripheral` selects the separate USB2 rescue graph. The accepted installed kernel and rollback images are not changed by source preparation.

Patch 0065 adds the full-profile DWC3 compatible, exact OEM clock rates, next-role VBUS-valid override and read-only role switch. The firmware/UCSI stack remains the only role producer. VBUS sourcing is not implemented through a raw GPIO, regulator or power-supply write. The existing OEM eUSB2/repeater sequence is exposed through one generic PHY instance only in the new profile; the legacy profile retains its existing USB PHY API. Full HOST no longer trips the legacy peripheral-only admission check.

The dedicated WCD driver admits the observed silicon value `0x01`, which the exact OEM enumeration defines as Harmonium 2.0. Its single I2C owner registers standard Type-C orientation and mode switches, retains USB2 during four-lane DP, uses exact O82 fuse overrides and validates the OEM AUX switch status before reporting success. Analog audio modes and unknown silicon are rejected. No codec/audio success is claimed. WCD 1.x support must not be inferred from its product-family name.

Patch 0066 connects the regulator-facing GCC PHY GDSC without mapping GCC twice. QMP uses the exact L3B, L4B and L2B supplies, OEM USB voltage/load votes and separate DP votes. It returns PHY configuration and route restoration errors, refuses a route change over a powered DP link, and records an uncertain power transition instead of retrying it blindly. A failed forced restart must not release votes twice. Retained uncertain votes require coordinated recovery.

The full overlay preserves the real GIC/PDC interrupt description, replaces the inherited fixed PIPE parent with the real QMP clock provider, replaces the legacy USB PHY reference with generic PHY references and connects all standard connector endpoints. DWC3 remains capped at Gen1, 5 Gbit/s. IRQ 131 and another board's GIC cell count are not copied.

The native display overlay creates the exact OEM DP instance at `0xaf54000`, MDSS IRQ 12, DPU INTF0, QMP AUX/link/clock graph and DP HPD bridge through the firmware connector. The link rate remains at or below HBR2. The accepted internal O82 DSI/DSC timing and topology remain intact.

Display patch 0044 adds the Uke external connector's standard maximum-bpc property, derives color depth from EDID, the user's maximum and actual lane/rate bandwidth, and selects the matching DPU RGB101010 output when the selected depth is ten. Other DPU outputs retain their existing format. Existing DP debugfs reports mode, link lanes/rate and actual selected bpp. A maximum-bpc property is a ceiling, not proof of ten-bit transmission; bandwidth fallback is reported through actual bpp. Four HBR2 lanes may be required for 2560x1440 at 75 Hz and RGB ten-bit, depending on its exact timing. Firmware must actually negotiate the required pin assignment. Two-lane DP plus USB3 cannot be assumed sufficient.

CDC is disabled by default in the new native command line. The full initramfs removes early legacy CDC service activation links and rejects a stale debug command-line fragment. The matching root support package provides manual `uke-control set cdc on|off` and the sole configfs owner. No automatic root shell, ECM or hotspot is enabled. An explicit existing peripheral rescue image remains separate.

## Source evidence and corrections

| Source | Exact evidence | Use and limit |
|---|---|---|
| MiCode kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd` | `drivers/soc/qcom/wcd939x-i2c.c`, WCD register headers, `drivers/usb/phy/phy-msm-snps-eusb2.c`, USB repeater and QMP source | Uke switch revision, init/route sequence, power and repeater behavior. Source evidence does not qualify the new Linux framework integration. |
| MiCode DT `94c84aeb9e517dbde546fc732033c184094c8e57` | `qcom/cliffs-usb.dtsi`, `qcom/uke-sm8635.dtsi`, PM7550BA graph | Board supplies, resets, IRQs, tuning and maximum speed. |
| MiCode display `44275c404a677d9d9e5230fedd1af2ef02fc7b9a` and display DT | `display/cliffs-sde.dtsi`, O82-42 panel DT | DP MMIO/IRQ, PHY supplies and HBR2 ceiling; internal panel uses 30-bpp input. |
| OnePlus same-SoC kernel `fc892483f1d61f245924681eb5abd563564d9cba` | WCD/eUSB2 shared-IP implementations | Comparison only; no foreign board tuning or donor scripts are executed. |
| Upstream Linux 7.2.10 / reviewed source snapshot `4056b3c9d3c92ea45955641dbafeb9b960e146ef` | QMP combo, Type-C mux/UCSI, DP/DPU, shared-IP SM8650 graph | Standard framework/lifecycle patterns. The SM8650 board's extra IRQ and firmware/power configuration are not Uke evidence. |

Corrections to preliminary inspection: QMP analog rails are L3B/L2B/L4B, not L1G. WCD revision `0x01` is 2.0, not 1.x. The generic DRM bridge connector's default eight-bit field applies to its HDMI initialization branch and did not establish a DP limitation; the actual DP source gap addressed here was the fixed RGB888 DPU output.

## Cached diagnostic interfaces

18 October follow-up, Linux 7.2.11 source candidate: AUX validation now reads
`SWITCH_STATUS1` at `0x407` and compares only mask `0xcc`. The earlier address
`0x406` is `SWITCH_STATUS0`, which reports USB DP/DM rather than AUX. Exact Uke
MiCode `5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
`drivers/soc/qcom/wcd-usbss-registers.h` and
`drivers/soc/qcom/wcd939x-i2c.c::validate_display_port_settings`, define the
masked `0x48` / `0x84` AUX states. OnePlus
`fc892483f1d61f245924681eb5abd563564d9cba` agrees. Upstream Linux 7.2.11
`a2de78ee6ed8bf8cd99d177c74865a6e8c3cb6ea` routes AUX through the same selector
but does not implement this status check. No register write, tuning value or
power policy changes in this correction.

The actual driver apply function passes GCC and Clang host fixtures covering
all 256 status bytes in both orientations, unrelated microphone/ground bits,
read/write failures, USB-only routing and removal. The earlier source fails
this fixture. Source preparation runs it before compiling the kernel. These
results do not establish a live AUX read, EDID, link training or HDMI output.

`route_state` on the WCD device contains version, last confirmed orientation/mode/SVID, revision, applied flag and errno. `applied=0` invalidates the previous route after a failed request. AUX status is checked during application, never by reading this attribute.

`uke_route_state` on the QMP device contains version, requested orientation/mode, reference counts, DP powered flag and fatal restoration errno. It does not claim link training, measured power, actual USB enumeration or monitor acceptance. Both attributes are read-only cached observations and send no GLINK request or PHY/I2C transaction.

The chosen `senemos,usb-profile="typec-v1"` property identifies the compiled source composition. It is not a physical qualification token or authorization to override firmware power roles.

## Combined delivery and remaining acceptance

The coordinator must combine this source with charging backend, root manual-CDC support and application updates, preserving the updater, recovery route, matching modules and rollback tuple. First inspect the final effective FDT and complete translation units; old synthetic contracts alone are insufficient. Record source, compiler/test, package and tablet outcomes separately.

Physical acceptance remains open: USB2 low/full/high speed, Gen1 in both orientations, HOST input/storage/Ethernet/audio, host while charging, negotiated source/sink and power limits, full suspend/resume, repeated attachment and firmware restart recovery, DP AUX/HPD, monitor EDID, independent extended desktop, 2560x1440 75 Hz and actual 30-bpp output, hub charging/data/display concurrency. Analog USB-C audio and manually requested power-role/VCONN swaps remain unavailable until their actual backend and codec/firmware path are qualified. External HDR/MST/VRR, USB4, HBR3 and ten-gigabit USB are not advertised by this profile.

The separate charging owner supplies real threshold/current firmware transport with readback and runtime control. This USB source does not set an 80% threshold, certify active charging or replace that backend with a desktop icon.

The internal panel's advertised 12-bit/68.7-billion-color, DCI-P3 and 800-nit HBM specifications are distinct from the exact O82 ten-bpc DSC link. A 12-bpc link, measured gamut, HDR calibration and 800-nit optical output are not established by changing metadata. The coordinator owns the internal display/color/backlight extension and Fastfetch's 11.2-inch presentation. Product references: [global specifications](https://www.mi.com/my/product/xiaomi-pad-7/specs/), [12-bit and HBM specifications](https://www.mi.com/in/product/xiaomi-pad-7/specs/).

Source follow-up 0068 checks generic PHY mode errors before starting the new
host/gadget after the previous role is stopped. The full profile's read-only
role value comes from successful driver initialization rather than the earlier
GCTL request. Failed initialization returns the cached role to none, records
the error and removes the VBUS-valid override. This completion state still does
not prove USB enumeration, negotiated PD power or physical operation.

Coordinator preflight found that Linux hides the entire role attribute when
userspace control is disabled. Patch 0069 adds an explicit descriptor opt-in
for read-only observation. Only the Uke full profile opts in. The role attribute
is then 0444, and its store callback independently rejects access with EACCES
before parsing or invoking the setter. UCSI/kernel callers retain control.
The default hidden interface and existing control-enabled switches retain their
visibility. The new host fixture extracts actual registration, visibility,
show/store and kernel role API functions; it checks registration flag copying,
read-only exposure, direct store rejection, kernel control and requested versus
observed state. It is prepared for the coordinator and has not run in this
source task. Full kernel compilation remains a separate check.

The coordinator's first native-profile preparation rejected display entry patch
0002 because its expected boot log line still named the old fixed peripheral
profile. The source successor refreshes that exact context and the resulting
log text for the selected USB profile. The patch is still applied through the
normal checked producer; no failed hunk or graph check is bypassed. A successful
preparation/build receipt remains the coordinator's separate result.

The full controller also declares standard `wakeup-source`, so system suspend
can use its supplied OEM PDC lines. Patch0070 makes DP/DM/SuperSpeed wake IRQs
mandatory in this full profile and propagates deferred/missing providers;
otherwise the inherited optional lookup silently loses wake capability.
The fixed peripheral profile keeps optional lookup semantics. Neither the
property nor successful IRQ registration proves physical wake or suspend
stability; those remain coordinator acceptance cases.
