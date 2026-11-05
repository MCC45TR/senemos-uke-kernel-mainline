# Uke WN8030 kernel candidate

5 November2026: [conditional backlight and ordered power](../../docs/POGO-BACKLIGHT.md)
adds a standard LED only while attached, preserves reconnect brightness and
gates input/output until the host authentication token is delivered. Effective
accessory acceptance is still a separate result. Native source/object checks
run in COPR; cumulative kernel delivery belongs to the shared coordinator.

4 November 2026: the candidate compiles and passes complete-package checks in
COPR11252339, kernel7.3.1-2313. Physical accessory support remains under
qualification. The controller is
the exact Uke I2C SE3/0x4c route. It requires the private, locally retained
82,740-byte Global OS3.0.304.0 MCU RAM image; no firmware is distributed here.

The driver implements checked RAM upload, bounded I2C transfers, HID keyboard
and a candidate three-contact touchpad, attachment through SW_DOCK, Caps Lock,
microphone mute and keyboard backlight LEDs, keepalive, exact Uke reset/wake
timing, lid inhibition and system sleep. The existing SMP2P Hall devices own
lid/tablet state; this driver does not claim their physical GPIOs.

Control messages use prefix 0x4c. Boot commands use 0x5c and retain the Uke
3 ms write pacing. The exact image hash is checked before GPIO/power activity.
No flash update, arbitrary bus-write interface or other-board firmware fallback
is exposed. Static comparison with the exact Uke archive9bb7c43/module0f24da97
confirms the21-byte hybrid format: three entries per packet and a maximum
of eight contacts per frame, X3199/Y2135 and advertised94x42mm. The previous
donor Y1770, unspecified dimensions and total-three limit are corrected.
The standard upstream HID multitouch layer handles continuation packets.
Actual accessory reports, optical/electrical behavior and measured dimensions
remain unqualified. Unknown packed/pressure formats are not silently interpreted.

Authentication is asynchronous. Root reads the versioned auth_request sysfs
attribute and supplies an epoch-matched auth_token within five seconds. The IRQ
never waits for userspace. Disconnect and suspend invalidate pending tokens.
Sending a token is not proof that the accessory accepted authentication. A
qualified Uke trusted-app userspace provider remains required; no TEE or secure
storage operation has been performed.

Protocol/descriptor provenance: map220v's GPL-2.0-only WN8030 implementation,
as retained in yzddmr6/linux-sm8750-piano at
8ee5a1576e123ecbacfcfb9925d0f56820132bb8. Uke wiring, polarity, firmware and
control-prefix evidence are recorded in the canonical Focus input research.
Source, COPR compilation, package delivery and physical accessory results must
be reported separately.
