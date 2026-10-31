# Uke CPU and power source review

31 October update: Linux 7.3.1-3 is now installed. Its three boost lists are
empty, and the standard global write returns EINVAL because no policy
supports boost. The proposed initializer is held and removed from source
preparation. Its guard fixtures established machine scope, not hardware
capability. Setting the global bit cannot add a missing firmware LUT entry.
The original global/policy bits and all CPU min/max bounds were restored
after the rejected attempt. The observations below remain dated history.

30 October 2026. The observed POCO Pad X1 runs Linux 7.3.0-54 with
`qcom-cpufreq-hw`, three shared policies and the `uke-qos` balanced profile.
The requested 7.3.1-3 COPR candidate is a separate build; these changes do
not modify its source identity or establish installation on that candidate.

The A520, A720 and X4 policies respectively expose 364800–1900800,
480000–2611200 and 480000–2803200 kHz. Their current minimum requests
already equal the hardware minimums. Separate boost lists are empty in
this observation. A nonzero global boost permission therefore must not be
reported as an additional frequency, overclock or performance result.

The MiCode Uke kernel at `5712080a4b0c0b1a879e6d145c601c649ddaddfd`
and OnePlus SM7675 kernel at `fc892483f1d61f245924681eb5abd563564d9cba`
both set `cpufreq_qcom_hw_driver.boost_enabled` to true in
`drivers/cpufreq/qcom-cpufreq-hw.c`. Their EPSS parser distinguishes real
core counts from the older count-one turbo sentinel. The existing Uke
patch already preserves the three-, four- and one-core domains. The new
boot patch restores the OEM boost permission only on a machine matching
both `xiaomi,uke` and `qcom,sm7675`, before policy registration. It retains
the standard CPUFreq control and changes no firmware LUT or voltage.

The exact Uke DT at `94c84aeb9e517dbde546fc732033c184094c8e57`,
`qcom/cliffs.dtsi`, supplies the three CPU domains and PSCI idle states.
`qcom/cliffs-thermal.dtsi` supplies emergency CPU pause maps, and
`qcom/uke-sm8635.dtsi` supplies board thermistors. The existing Uke
conversion retains thirteen 110000 mC CPU emergency trips with their
8000/10000 mC hysteresis and replaces unavailable vendor CPU pause with
standard shared-policy CPUFreq cooling. This is not the complete Android
skin, scheduler or battery-current thermal policy. Generic 125000 mC
placeholder trips must not be described as a calibrated board policy.

The observed suspend counters are success=0, fail=1, errno=-16, without a
failed device or stage. An s2idle request returned immediately. Touch
gesture errors and supplier sync-state warnings are separate observations;
neither is established as the cause of this early abort. The existing
PSCI idle counters include core and cluster power-collapse entries. Their
counts do not qualify system suspend or system-wide low-power residency.

A later readback identified a different boot with the same kernel and
success=0, fail=0. These counters reset across boots; the new zeros are
not a suspend fix. The previous journal retains entry/exit at monotonic
312.764032/312.764206 seconds, followed by completion of filesystem sync.
Upstream `kernel/power/suspend.c` can return `-EBUSY` before device suspend
on a busy system-transition mutex, and `kernel/power/main.c` can return it
while filesystem sync waits with a pending wake event. These are bounded
early-abort hypotheses, requiring a traced, attended reproduction.

Retain `regulator_ignore_unused`, `clk_ignore_unused` and
`pd_ignore_unused` until the affected native suppliers, consumers and
runtime votes have been inventoried. Remove only a separately qualified
workaround, with a matched recovery build. Do not substitute an automatic
deep-suspend default for lifecycle investigation. Physical wake, sustained
frequency, thermal protection and suspend power remain separate gates.
