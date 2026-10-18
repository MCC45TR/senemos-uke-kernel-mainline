# Mainline display source profile

17 October 2026. The native O82 profile is part of
`senemos-uke-linux-kernel-mainline`; there is no separate native kernel package.
The root `make srpm` and `.copr/Makefile` use one specification and source
producer. `packaging/native/Makefile` remains a compatibility SCM entry pointing
to the same producer. EL2 work remains separate.

The source RPM contains signed Linux 7.2.10, the 49 ordered Uke base patches,
the ABL adaptation, native DPU/DSI patches, the exact O82-42 seven-mode overlay,
configuration, contract checks, source commit and asset hashes. Integer releases
use separate module paths: `7.2.10-2`, `7.2.10-3`, then `7.2.11-1` when that
upstream version is separately pinned. Install-only packages do not obsolete
or overwrite a previous kernel build.

Release 2 restores the source-built boot tuple: Image, matching modules,
independent DTB/native overlay, and a kernel-only Android v4 boot container.
The dracut base is generated on the AArch64 build worker from original Fedora
packages. The 376 early modules follow the native56 inventory with PAS excluded;
PAS starts after the real root supplies OEM firmware. The native updater writes
only when its local configuration explicitly enables automatic updates. It keeps
the previous full image and validates readback. Release 4 passes signed COPR
artifact checks and normal persistent tablet boot; the earlier native56 boot
is separate evidence.

Commit `4eb69e5`, published as `feature/dnf-stock-abl-updates-20261015`, contains
a dracut and guarded boot-container producer. Release 2 integrates its source
with the current O82, SSC, Bluetooth and bounded CDC startup configuration.
Private initramfs files, firmware, credentials and
per-device calibration are not source inputs here.

Upstream Linux's MSM register generator
`drivers/gpu/drm/msm/registers/gen_header.py` has SHA-256
`81763fc03ea0ebf254ab7427af2113dc0c7c0d80dceab61232b6e371463d1f90`.
It converts upstream XML into register headers and is an unavoidable host-only
Python build dependency. No project Python or Python payload is supplied to the
tablet; package installation checks reject Python files and runtimes.

## PMIC and CPU thermal candidate, 18 October 2026

Release 3 introduces the source change; release 4 admits the exact OEM PMIC ADC graph through upstream ADC5 Gen3,
IIO, iio-hwmon and generic-adc-thermal. It exports 23 supported channels and
connects ten board thermistors to their existing thermal zones. Four private
charger scalers remain unexported; GLINK battery telemetry remains separate.
Processed voltage uses the IIO millivolt ABI, including the two divided-voltage
channels previously classified as temperature by the upstream table.

Thirteen OEM emergency cooling maps are connected to the three standard
cpufreq cooling devices. The OEM 110 degree junction triggers and respective
8/10 degree hysteresis remain unchanged. Vendor CPU pause is replaced by
frequency cooling; the complete OEM skin and BCL policy is not implemented.
The exact release 4 COPR bundle boots normally. Its 23 IIO channels, ten board
thermal consumers and thirteen CPU cooling bindings are present. The full
installation has 67 readable hwmon temperature inputs and 51 thermal zones,
including overlapping measurements. Software-emulated thermal events lower
all three CPU policy limits and the GPU cap; all emulation is cleared afterward.
Actual heat protection and sustained workloads remain unqualified.

Release 5 adds a tested SMP2P history guard: ordinary entry notifications cannot
replay asserted ADSP ready/handover edges. Both genuine restart transitions
still reset input history. COPR 11165033 passes signed artifact checks; DNF
delivery and boot-B readback pass. Bounded tablet traces confirm the corrected
edge handling. Subsequent normal KDE reboots reach the installed system; the
first release-5 boot follows a forced power cycle. Full shutdown remains open.

Release 6 adds the four previously excluded OEM charger/battery ADC scalers,
with signed current, standard mA/mC units and a distinct battery thermistor
binding. The graph retains all 27 OEM channels. Full-code arithmetic sweeps,
battery monotonicity and malformed-resource refusal fixtures pass on the host.
COPR and tablet acceptance remain separate gates.

Release 7 maps the exact OEM lid/table SMP2P entries to standard EV_SW input
devices. The kernel reads remote open/closed line state and ignores missing or
conflicting initial reports. It neither acquires SSC-owned GPIOs nor introduces
polling or a startup service. Host state/refusal tests and the exact OEM graph
pass; normal module startup and physical Linux switch events remain separate
tablet gates.

Release 8 combines these sensor changes with the separately reviewed bounded
O82 video AVR experiment. Host checks pass against the combined source.
The read-only module parameter defaults to zero; no connector capability or
qualified VRR range is advertised. Physical activation tests use the separate
[AVR procedure](../../docs/O82-VRR-EXPERIMENT.md) after package delivery.

Release 2 compiles the full kernel but fails the early-PAS guard because its
module inventory includes PAS. Release 3 is cancelled before repeating that
known packaging fault. Release 4 removes PAS from the early inventory and
keeps the fail-closed check. No failed bundle is installed on the tablet.

Combined release 8 passes signed COPR 11165188 delivery, boot-B readback and
normal KDE reboot. The Hall module and both input devices appear automatically; physical lid and rear
fold/unfold events pass through standard evdev, and logind tracks the lid.
All 27 PMIC channels appear in IIO, hwmon and the original KDE backend with
standard units. Internal charger temperature reads 31.29–31.41 °C with USB
power. Without USB power its near-zero input produces the OEM-clamped 0 °C,
which is not a measured ambient temperature. Independent conversion checks
pass; absolute calibration remains unqualified. Battery temperature
and signed current feedback values are readable. Cover display policy, closed
cover boot, calibration accuracy and real heat protection remain unqualified.
The included AVR code defaults off and lacks the standard CRTC property
attachment; activation testing remains a separate continuation.

The 18 October 2026 Bluetooth candidate translates the exact selected Uke UART
wake interrupt to the falling edge requested by its OEM driver. The upstream
wake-IRQ helper retains the DT trigger, so keeping the OEM level cell causes
repeated runtime-PM wakeups. Host FDT fixtures preserve the other IRQ cells and
reject foreign graphs. Standard Bluetooth LE and modular BNEP are enabled for
the original desktop services. Matched package, idle-IRQ and Bluetooth device
validation remain separate from these source checks.

A separate 18 October source correction removes only the exact unused legacy
VA scalar qcom,is-used-swr-gpio=1. Upstream OF interprets its suffix as a GPIO
specifier and incorrectly resolves value 1 to the interrupt controller. The
actual FDT helper preserves native compatibles and other values. This does
not enable audio or alter the SoundWire pinctrl reference; tablet warning
validation remains pending.

## Full Type-C source candidate, 18 October 2026

The versioned `usb-profile` now selects `typec-v1` for the next combined native
build. It connects UCSI/HOST, Gen1 and external DisplayPort through the exact
Uke PHY, WCD and clock graph. CDC defaults off; the matching root manager enables
it only after an explicit user request. The existing accepted peripheral kernel
remains the rollback. Source, build and device acceptance are separate; see
[the full-profile record](../../docs/USB-TYPEC-FULL-PROFILE-20261018.md) for the
source pins, interfaces, composition requirements and remaining physical gates.
