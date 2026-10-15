# PMXR2230 status LED candidate

Source review: 15 October 2026. Target: Uke, Linux 7.2.9.

The overlay translates Uke's OEM LED graph to the existing upstream
`leds-qcom-lpg` driver. It is a host-tested candidate; no boot profile loads it.
It does not establish that the tablet emits three visible colors.

The Uke OEM kernel at `5712080a4b0c0b1a879e6d145c601c649ddaddfd` provides
`drivers/leds/leds-qti-tri-led.c` and `drivers/pwm/pwm-qti-lpg.c` under GPL-2.0.
The OEM DT at `94c84aeb9e517dbde546fc732033c184094c8e57` selects the following
PMXR2230 register layout in `qcom/pmxr2230.dtsi`:

| Function | OEM register or channel | Upstream comparison |
|---|---|---|
| PWM channels 1–3 | `e800`, `e900`, `ea00` | `pm8350c_pwm_data` has the same channel bases |
| Additional PWM | `eb00` | Same fourth channel; no LED is assigned to it |
| LED output enable | `ef46`, bits 7, 6, 5 | Same tri-LED base, enable offset and channel masks |
| Pattern storage offsets | `48`, `56`, `64` | Same upstream descriptor; pattern storage is excluded from this candidate |

The OnePlus Nord 4 Android 16 modules/DT source at
`1138e00fee63582a0cc6a53af3286621786827b7` contains the same PMXR2230 include.
This is a shared peripheral comparison, not board-level evidence.
Linux 7.2.9's `drivers/leds/rgb/leds-qcom-lpg.c` already supports this register
layout through `qcom,pm8350c-pwm`. The candidate reuses that descriptor through
a standalone `qcom,pmxr2230-pwm` compatible; it adds no replacement controller
driver. An older driver cannot use a fallback compatible to bypass admission.

The old vendor PWM/tri-LED nodes are disabled together to prevent overlapping
owners. The replacement exposes three ordinary Linux LED class devices, all
off by default, named from their standard color and status function properties.
It changes PWM duty and output gating through the upstream
driver, without introducing current, supply-source or calibration overrides.
It does not import the vendor timer trigger, SDAM LUT, PBS pattern programming
or flash LED configuration. Breathing and autonomous patterns remain pending.

Stock Android read-only records show `leds-qti-tri-led` actually bound to
PMXR2230 `leds@ef00` and `pwm_qti_lpg` bound to its PWM nodes. The Lineage common
device source at `d3e10662e157f273a43755a296db98063ace01f0` names red, green and
blue sysfs paths, but its capability mask is 232 and omits the RGB capability
bits. Controller binding and channel labels therefore do not prove emitted
colors or the assembled LED topology. Fedora currently exposes no LED class
device for this peripheral.

`pmxr2230-driver.patch` reads the OEM tri-LED type and subtype registers and all
four PWM subtype registers before the first output write. It accepts the
reviewed PWM, high-resolution PWM and LPG-lite formats. It rejects failed reads,
unknown formats and the LED2H0L12 tri-LED subtype, whose OEM code can require a
PBS supply sequence. It does not change that supply sequence or LED current.

`make test-led-overlay` compiles the overlay, applies it to an independent
minimal OEM graph and checks ownership, channel numbering, default-off state
and absence of pattern/current overrides. An optional `UKE_LED_TEST_FDT` input
checks the same graph on a private captured Uke FDT. These are host graph tests.
They are not DT schema validation or hardware acceptance.
`make test-led-admission SOURCE_TREE=/path/to/linux` applies the driver patch and
compiles its actual admission function against register-read fixtures. The
fixtures cover accepted types, the PBS-dependent type, unknown values and every
register-read failure; the extracted function contains no hardware write.

Before activation, the boot integration must reject a foreign board or a
different PMIC/PWM graph and build the driver with the subtype guard.
`pmxr2230-binding.patch` describes the new compatible; it is not applied by any
admitted kernel profile and still requires schema validation. Blindly applying
the overlay does not implement the boot admission checks. The first physical test must retain a
recovery route, keep the default off and exercise one channel at low duty
while observing the result. No color-support claim should precede that test.
