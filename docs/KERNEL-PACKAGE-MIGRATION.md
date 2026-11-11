# Device support in the kernel and Device Tree

6 November 2026. POCO Pad X1 runs7.3.1-12211-unstable from B, following
COPR11269695 and configured repository DNF delivery. Full B, retained A12210
and modules, six signed RPMs, automatic staging and persistent rollbackoff
are verified. Native update status is complete B/B. Physical audio, Hall,
USB wake and full sensor acceptance remain open. See the exact
[qualification record](../manifests/kernel-migration-full12211-20261106.json).
The initial read-only survey classified59 project names/109 installed versions;
that historical count is not a removal instruction or physical acceptance.

Hardware resources, protocols and mandatory protection belong in DT/kernel.
Desktop policy, firmware files, image processing, D-Bus and RPM transactions
retain their normal userspace owners. Moving those interfaces into the kernel
would add incompatible responsibilities without eliminating the dependency.

## Current migration

Combined source `a73b16e022b1db49d710da39d1ab6094949a5aa5` passes
[COPR11266477](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11266477/)
in155 seconds. The signed text-only receipt, exact sources and additive patch
preimages are recorded in
[`kernel-migration-source-20261105.json`](../manifests/kernel-migration-source-20261105.json).
This initial result qualifies source/callback/object checks. Later cumulative
12211 passes full native, DNF/inactive-B delivery and matching B boot checks.
Protected graph OPEN succeeds, but its large configuration times out waiting
for a remote GLINK buffer. A real display-idle/RTC test reproduces USB host
removal. These results remain separate from hardware acceptance.

The native SSC IIO driver now reads the accelerometer child's standard
`mount-matrix` and exposes `in_accel_mount_matrix` through
`IIO_MOUNT_MATRIX(IIO_SHARED_BY_TYPE, ...)`. The early DT transformation carries
the existing Uke landscape transform:

```text
 0  1  0
-1  0  0
 0  0  1
```

This transfers existing board metadata from the SSC-only udev endpoint to the
standard IIO interface. Samples remain in firmware coordinates: the consumer
applies the matrix once. No physical sensor orientation, calibration or new
four-pose rotation result is inferred. Missing metadata stays absent. A present
declaration with other than nine strings refuses probe. The driver owns copied
strings and attaches metadata only to acceleration channels, not scalar
channels, the timestamp, gyroscope or magnetometer.

The existing legacy udev rule remains restricted to `misc/fastrpc-adsp` and
cannot apply a second transform to an `iio` device. It is retained for older
kernels until the distribution SensorProxy path passes separate acceptance.

## Package disposition

The exhaustive package patterns and reasons are in
[`kernel-package-migration.json`](../manifests/kernel-package-migration.json).
`bash scripts/kernel-migration-inventory.sh` checks installed project RPMs and
refuses unclassified or overlapping entries. It performs no service, sensor,
calibration, package or boot operation.

| Area | DT/kernel responsibility | Remaining userspace / withdrawal gate |
|---|---|---|
| Touch and pen | SPI, reset, firmware lifecycle, contacts, input events | Withdraw legacy client after both suppliers, complete input and recovery tests; private assets stay local |
| SSC sensors | QMI discovery/lifetime, physical units, IIO, mount metadata | Original SensorProxy is the target frontend; both ALS paths, axes, proximity, restart and suspend must pass before removing libssc-specific integration |
| DSP registry | FastRPC transport and remoteproc ownership | Filesystem service and protected local registry remain required by DSP firmware, including native IIO |
| Power profiles | Existing platform_profile/QoS and resource controls | Original power-profiles-daemon, persistent profile selection; retire the superseded backend only against the running provider |
| Battery/charging | power_supply telemetry and admitted actuators/protections | UPower, estimates, preferences and offline UI; generic daemon error/health/cache bugs need userspace fixes |
| GPU/display | DRM/MSM, panel/bridge, clocks, backlight and color registers | Mesa APIs/compilers, color assets, DDC and desktop policy; retire historical render-only loader when recovery permits |
| Video | V4L2 formats, controls, DMA and codec firmware transport | VA-API translation and media/session negotiation remain; these libraries are not hardware drivers |
| Cameras | CAMSS, clocks, sensor/EEPROM/actuator drivers | libcamera/IPA, tuning and AF algorithms; both fitted calibrated cameras and rear focus/parking remain required |
| Audio | ALSA/DSP/codec/amplifier, mandatory safety limits | UCM, WirePlumber/PipeWire, speech processing and orientation routing; existing protection and gain gates remain |
| Protected calibration | Validate runtime frames, DSP transport, limiting and fault muting | A small userspace loader reads local private calibration; do not move filesystem parsing or per-device data into the kernel |
| NFC/IR/pogo | Device protocols, HID/input, IR encoders, backlight and power | CLI/permissions, factory credential/firmware admission and desktop preferences remain |
| WLAN/Bluetooth | Transport, regulators, firmware requests, standard address interface | Exact factory identity currently comes from protected read-only persist files; no proven NVMEM cell justifies removing that loader |
| Firmware | request_firmware consumers and resource description | Separately versioned lawful firmware; never embed device-private calibration or addresses into public DT/Image |
| Boot/recovery | Hardware boot interfaces and signed module compatibility | DNF admission, staging, filesystem/RTC persistence and recovery tooling remain |
| KDE/GNOME | Correct standard hardware interfaces | Use original distribution packages; generic desktop defects cannot be implemented in DT |

Core1.0.7-20 absorbs the unchanged speaker-control metadata through a normal
versioned DNF upgrade; the standalone speaker-controls RPM is retired.
`uke-speaker-runtime` remains necessary for private read-only calibration
staging. The prospective
[shared-memory configuration core](PROTECTED-OOB-CONFIG.md) does not yet admit
a DMA backend or physical activation. Do not remove remaining audio/sensor
providers solely because a source fixture passes.

Front-light `9896de4` / check11263802 and rear-light `f4b5020` / check11264114
are separately qualified source contributions. The migration source check also
applies both patches to the retained layer2 acknowledgement consumer and checks
the combined source in both metadata/vector orders. The next cumulative assembly
must retain that combination. No physical ALS acceptance is claimed.

## Sources and compatibility

- Existing transform: support repository
  `0729581b315c9382d262903f118abd3bb5bc2b2a`,
  `uke-sensors/packaging/systemd/70-uke-ssc.rules` (project MIT integration).
- Exact OEM comparison: `Uke-resources/vendor_xiaomi_uke`
  `51ecce187b180e1df9230ff50b604af535b8e116`,
  `proprietary/odm/etc/sensors/config/sm7675_lsm6dso_0.json`.
  Its DSP orientation is `-x/-y/+z`; its optional placement values are zero.
  Those are different contracts from the panel transform. The proprietary
  reference is not copied into a package and no calibration field is imported.
- Native IIO ABI comparison: upstream Linux
  `79a907609d53d5cd645b42c11550d295d43abf99`,
  `drivers/iio/industrialio-core.c`, and current upstream
  `05441d697f7f9a927264f4058cbbc6a03dfcac9d`,
  `include/linux/iio/iio.h`,
  `Documentation/devicetree/bindings/iio/mount-matrix.txt`,
  `drivers/iio/accel/bma400_core.c` (GPL-2.0 subsystem code; original
  attribution is preserved). The generic mount reader supplies identity for
  missing metadata; this driver deliberately leaves an absent matrix unknown.
- The pinned SM7675 donor inventory and donor policy were consulted. Adjacent
  board matrices are not Uke evidence. The active Qualcomm SMGR IIO series
  uses a different service/protocol from SSC400 and is not substituted for
  the existing native consumer. No applicable same-SoC board matrix or queued
  Uke SSC400 mount implementation was established by this review.

## Delivery and acceptance

`packaging/native/copr-kernel-migration-check.sh` creates an essential remote
source fixture. Actual callback fault tests, three assertion mutants, the FDT
transformation and real AArch64 protocol/IIO objects are checked in COPR.
The kernel archive is fetched and hash-checked by the source worker, then
supplied as an RPM source so the native object check needs no network download.
The result contains text evidence only, with no service or driver installation.

The coordinator must apply the additive source delta to the latest complete
profile and boot recipe, retaining camera, audio, SSC ALS, pogo, governor and
manager contributions and all admission gates. A cumulative full-kernel build,
complete module/package checks, native DNF delivery and a separately coordinated
boot are still required. Original SensorProxy compatibility, measured four-pose
rotation, both ALS paths, restart/suspend and solver/upgrade/recovery checks
precede dependency changes or package retirement. Automatic staging and the
existing rollback preference remain persistent. No stable promotion is implied.
