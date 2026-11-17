# MiCode sensor comparison

17 November 2026. The current MiCode inventory contains 80 repositories. The
Uke kernel and camera branches still resolve to the previously admitted pins
`5712080a4b0c0b1a879e6d145c601c649ddaddfd` and
`699fa15a98abd40fbb94f3a6fc00f91723d29d35`.

The GPL MediaTek driver at
[MiCode mtkcam-kernel_device_modules](https://github.com/MiCode/mtkcam-kernel_device_modules/blob/bfd3e45948f5c1e1307ef6e217960596a08c5f61/imgsensor/src-v4l2/common/duchampov08d10ultra_mipi_raw/duchampov08d10ultramipiraw_Sensor.c)
provides an additional open OV08D10 protocol comparison. It selects two CSI
lanes, a 24 MHz source clock and the write-address list `0x6c, 0x20`. Its
`adaptor-subdrv.h` shifts these addresses right by one, and
`adaptor-i2c.c` uses the resulting `0x36, 0x10` in Linux I2C messages. These are
documented sensor probe options, rather than a measured Uke address.

Identification selects page zero through byte register 0xfd and reads bytes
0x00/0x01. The independently reviewed Intel and Rockchip GPL drivers identify
OV08D10 as 0x5608 at the same byte registers. The MediaTek driver's named sensor
ID macro is external to the reviewed module tree; its exact expansion has not
been established here. No source comparison was used as a physical sensor ID.

Duchamp's power table includes board GPIO rails, 1.8 V digital power and a
24 MHz clock. Uke's selected front description instead declares 19.2 MHz and
a 1.2 V digital consumer. Duchamp's board power table therefore cannot be
transferred to Uke. The native Linux driver already supports 19.2 MHz, but its
support list alone does not establish the fitted module or board sequence.

The selected Uke front description supplies the generic GENI8 sensor slot,
MCLK4, reset GPIO3 and the fixed AVDD regulator controlled by GPIO160. It also
describes the 1.8 V I/O and 1.2 V digital consumers, alongside other inherited
power entries. L20B's provider range is wider than the sensor's 1.8 V request;
enabling it without a scoped consumer request would be insufficient. These
are static, read-only DT observations, not physical voltage measurements.

Bounded searches of the existing local GPL kernel/camera sources and the
published Uke camera driver's C/H/build files have not found a Uke-specific
OV08D10/OV13B10 probe and power table. MiCode's GPL MediaTek module driver adds
useful protocol evidence, but does not close that board contract. This is a
search limit, rather than a claim that no such source exists. No live sensor
probe, bus scan, mode programming, EEPROM access or closed-HAL analysis was
performed for this comparison.
