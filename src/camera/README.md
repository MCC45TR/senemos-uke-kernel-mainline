# Uke camera sensor development

21 October 2026. Fedora Rawhide AArch64, running Linux 7.2.11-14: no
video, media-controller or V4L2 subdevice nodes were present. The OEM Cliffs
CAMCC, CCI and CSI PHY nodes had no matching bound Linux drivers. CAMSS was
configured as a module; OV08D10 and OV13B10 were disabled.

The optional [sensor fragment](sensors.config) selects Linux OV08D10 and
OV13B10 modules for a separate development build. Both source
drivers support the OEM-declared 19.2 MHz input clock. The fragment does not
enter the released configuration, generate a boot image or enable a DT node.
It is not included in the existing firmware Source4 payload. No camera module,
firmware, tuning or calibration data is supplied by this candidate.

The earlier generic OV13B10 binding and OF-match patches from source
`5c641724857dbc91a7480c1be100ff94b9f88bd7` are retained unchanged. They preserve
the original ACPI path and sensor register/power sequences. OV08D10 already has
OF matching. These prerequisite patches also remain outside the active series.

OEM plugin names identify these two sensor candidates; they do not replace a
live chip-ID check. The OEM front `reg = <0x20>` belongs to a generic Android
camera client and is not an independently verified sensor address. Do not use
an I2C scan, GPIO writes or another board's settings to fill this gap.

The native platform port must provide CAMCC power/voltage ownership, CCI where
required, the Cliffs CSIPHY/CSID860/VFE860 resources, IOMMU/interrupt/interconnect
contracts and a connected sensor graph. Current upstream CAMSS has no SM7675
match. A neighboring compatible string cannot supply these contracts. Only
then can a controlled sensor identity probe, RAW capture and the original
Fedora libcamera pipeline be qualified on the tablet.

See [the pinned source record](../../manifests/camera-source-candidate-20261021.json).

With a prepared Linux 7.2.11 source and an AArch64 LLVM build environment, run
the object check in a new disposable output directory:

```bash
make test-camera camera_source=/path/to/linux-7.2.11 camera_output=/path/to/new-camera-output
```

This checks both upstream preimages, applies the existing OV13B10 prerequisites
to a small disposable source copy, merges the optional fragment into ARM64
defconfig and builds both objects with warnings treated as errors. The output
directory must not already exist. It does not alter the prepared source or
build loadable modules, a kernel or a tablet payload.
