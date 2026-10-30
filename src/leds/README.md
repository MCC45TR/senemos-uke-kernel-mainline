# Uke kernel light ownership

30 October 2026. The existing RGB consumer owns notification policy. The torch
consumer adds a separate `senemos,uke-torch` DT node and `/dev/uke-torch` ABI 1.
Both use managed LED suppliers; neither accesses PMIC registers directly.

Torch admits only the existing Uke/SM7675 torch-only QCOM provider, channels 1
and 4, max brightness 2 and 20,000 microampere total ceiling. It owns sysfs stores
while bound. Percentage mapping, the remembered positive request, exclusive
writer and off on close, sleep, reboot and removal are serialized by its mutex.
The state allocation remains valid until the last open descriptor is released;
a dead consumer returns `ENODEV` without calling a removed provider. An output
failure attempts off and preserves the first error; an unsuccessful fallback
marks brightness unknown. No new deadline, current ceiling, regulator or flash
mode is introduced.

`tests/torch-lifetime.sh` and `tests/torch-supplier.sh` execute actual source
functions with simulated primitives. `tests/fixtures/torch-control-check.spec`
is an isolated COPR native-check recipe. It builds Control, runs its checks and
compiles this consumer against the recorded official Fedora kernel headers.
Its output RPM contains text receipts only, with no runtime or kernel module.
These checks do not replace a complete matched Uke kernel/DT build or attended
physical validation. The existing kernel release number is not allocated to
this candidate; any later runtime build needs a fresh release and recovery plan.

The electrical graph remains the accepted `src/boot/sm7675-uke-lights.dtsi`.
The reviewed Uke OEM DT source is MiCode/kernel_devicetree commit
`94c84aeb9e517dbde546fc732033c184094c8e57`, including `qcom/pmxr2230.dtsi`.
The generic OEM node alone does not prove the fitted board's channel selection;
the retained FDT checks in `tests/light-dt.sh` remain required. The implementation
uses the upstream LED consumer, synchronous brightness and device-link APIs,
retaining the original QCOM flash driver's current programming.
