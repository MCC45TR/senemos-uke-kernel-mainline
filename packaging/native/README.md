# Mainline display source profile

17 October 2026. The native O82 profile is part of
`senemos-uke-linux-kernel-mainline`; there is no separate native kernel package.
The root `make srpm` and `.copr/Makefile` use one specification and source
producer. `packaging/native/Makefile` remains a compatibility SCM entry pointing
to the same producer. EL2 work remains separate.

The source RPM contains signed Linux 7.2.10, the 46 ordered Uke base patches,
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
the previous full image and validates readback. The new producer needs its own
COPR artifact and tablet acceptance; the earlier native56 boot is separate evidence.

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
These are source and fixture results until the exact COPR bundle boots and the
new channels and cooling bindings are inspected on the tablet.

Release 2 compiles the full kernel but fails the early-PAS guard because its
module inventory includes PAS. Release 3 is cancelled before repeating that
known packaging fault. Release 4 removes PAS from the early inventory and
keeps the fail-closed check. No failed bundle is installed on the tablet.
