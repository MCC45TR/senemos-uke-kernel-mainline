# Uke camera sensor development

21 October 2026. Fedora Rawhide AArch64, running Linux 7.2.11-14: no
video, media-controller or V4L2 subdevice nodes were present. The OEM Cliffs
CAMCC, CCI and CSI PHY nodes had no matching bound Linux drivers. CAMSS was
configured as a module; OV08D10 and OV13B10 were disabled.

The optional [sensor fragment](sensors.config) selects Linux OV08D10 and
OV13B10 modules for a separate development build. Both source
drivers support the OEM-declared 19.2 MHz input clock. The fragment does not
enter the released configuration, generate a boot image or enable a DT node.
The development Source4 producer carries these inactive assets for source
review; it does not apply them or merge the fragment. Previously published RPMs
are unchanged. No camera module, firmware, tuning or calibration data is supplied.

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

## Camera clock data

The [SM7675 clock catalog](camcc-sm7675-data.h) combines attributed native
register data with all 44 exact Cliffs voltage policies. Tests compare 209
register fields, 86 frequency rows and 147 clock/reset IDs with the OEM source.
PLL HIGH_L1 entries outside the declared supply-class ceiling are omitted;
the valid OEM frequency/voltage points remain. These are symbolic RPMh levels,
not measured rail voltages.

The proposed `qcom,sm7675-camcc.h` retains 137 clock IDs and 10 reset IDs and
adds the native donor's eight power-domain IDs. This remains a source ABI for
disabled board work. No driver, OF match, kernel configuration or boot producer
registers this catalog. Controller and GDSC PM ownership, interface clock/MMIO,
CRM/shared-RCG behavior and live voltage-vote callbacks must be completed before
activation. The catalog cannot make the existing OEM nodes usable on its own.

With the sensor test's prepared ARM64 output and the exact OEM checkout, run:

```bash
make test-camcc-data camcc_source=/path/to/linux-7.2.11 camcc_oem=/path/to/oem/drivers/clk/qcom/camcc-cliffs.c camcc_output=/path/to/camera-output
```

The check imports the real kernel voltage lookup, compares every legal OEM
policy and compiles the complete catalog as an AArch64 object. It models rail
metadata; it makes no regulator, register or firmware request.

[Board and EEPROM resources](board/README.md) retain disabled consumers for
both sensor candidates and read-only EEPROM model definitions. Their DT/schema
test uses the same proposed clock header:

```bash
make test-camera-board camera_source=/path/to/linux-7.2.11
```

Effective sensor addresses, lane maps and the rear EEPROM address remain
unresolved. These fragments do not provide a complete capture graph.

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
