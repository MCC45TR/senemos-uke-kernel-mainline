# Uke camera board resources and EEPROMs

21 October 2026. Inactive Linux 7.2.11 source candidate for Uke / SM7675.
This directory adds native resource fragments for both camera candidates and
AT24 binding support for the EEPROM models named by the OEM plugins. It
does not provide a complete board graph, enable a camera or modify a release.

| Resource | Front candidate | Rear candidate |
|---|---|---|
| Sensor | OV08D10 | OV13B10 |
| Control bus | QUPv3 SE8, GPIO0/1 | CCI0 master 1, GPIO72/73 |
| Master clock | MCLK4, GPIO68, 19.2 MHz | MCLK0, GPIO64, 19.2 MHz |
| Reset GPIO | GPIO3 | GPIO14 |
| Analog supply | GPIO160, 2.8 V | GPIO79, 2.8 V |
| Digital / I/O supplies | L3C / L20B | L6E / L20B |
| EEPROM model candidate | GT24P64E | BL24SA64 |
| EEPROM client address | OEM declares `0x51`; effective address unqualified | Not declared by OEM DT |
| CSI PHY index declared by sensor | 4 | 1 |

These values come from Xiaomi's
[Uke camera DT](https://github.com/MiCode/vendor_qcom_proprietary_camera-devicetree/tree/57d2135ee6909ffb7d288a7dc4d82c85d95fc10d),
`uke-sm8635-camera-sensor.dtsi` and `cliffs-camera.dtsi`. The OEM changes
CSIPHY0's compatible but the rear sensor selects index 1; this discrepancy
must be resolved before constructing the native graph. Native sensor reset
semantics follow their Linux bindings; electrical polarity remains a device
acceptance item. No adjacent board's addresses or calibration offsets are used.

The resource fragment requires `uke_camera_front_sensor` and
`uke_camera_rear_sensor` labels supplied by a separately verified native board
description. It deliberately supplies no sensor address, compatible, lane map,
link frequency or endpoint. The host fixture defines empty labels only to test
resource syntax and phandles; it cannot boot or capture an image. Native bus
providers must select the unused bus pin states after ownership is established.
The candidate CAMCC header is supplied by the separate provider source work.

Both AVDD regulators and both sensor resource consumers remain disabled.
The AVDD default state selects only its active pin configuration; the sleep
state contains the pull-down/output-low setting. The OEM's combined active
and sleep `pinctrl-0` is not reused. Shared S2B/BOB supply votes, PMIC regulator
parentage, native CAMCC voltage/CRM ownership and sensor power sequencing still
need qualification; the three native sensor supplies do not establish that
the full OEM shared power contract is satisfied.

The EEPROM patch extends the existing `at24.yaml` model list. The unchanged
Linux `at24` driver implements the `atmel,24c64` fallback. The front DT candidate
disables the old Android EEPROM client and declares a disabled native client
with 8 KiB, 16-bit addressing, the OEM L20B supply and `read-only`. `pagesize = 1`
is conservative metadata; programming remains prohibited. No calibration cells,
checksum offsets, software write-protection commands or address programming are
added. NVMEM's root-only default is retained. This is software write prevention,
not a hardware protection-lock operation.

Model evidence is separate from fitted-device identity: the static
OS3.0.304.0 module names identify GT24P64E and BL24SA64 candidates. Xiaomi's
[camera kernel](https://github.com/MiCode/vendor_qcom_opensource_camera-kernel/tree/699fa15a98abd40fbb94f3a6fc00f91723d29d35)
accepts userspace-supplied slave addresses and memory maps. In particular,
CCI shifts its Android address right by one; ordinary I2C assigns its supplied
address directly. Neither a default client address nor a scan establishes the
effective address. The rear EEPROM DT node is deferred rather than inventing
an address. Fitted identity and address-width verification must precede even
an `at24` probe, which performs an initial read.

[Belling's BL24SA64 V1.08 datasheet](https://www.belling.com.cn/media/file_object/bel_product/BL24SA64/datasheet/BL24SA64-CS_V1.08_en.pdf)
describes 8 KiB with two-byte addressing.
[Giantec identifies GT24P64E as 64 Kbit](https://www.giantec-semi.com/news/126);
the exact
[Coreboot telith declaration](https://github.com/coreboot/coreboot/blob/07f7c02983b0bae7bfb5abf6954b9ee17b186eb8/src/mainboard/google/brya/variants/telith/overridetree.cb)
uses an 8 KiB, 16-bit, read-only AT24C64 representation. This is shared-component
protocol evidence, not portable Coreboot board wiring or Uke hardware validation.

## Host checks

Use the prepared Linux 7.2.11 tree and the separate native CAMCC include tree:

```bash
bash tests/camera-board-contract.sh /path/to/linux-7.2.11 /path/to/camera/include
```

The test checks the exact upstream binding preimage, fresh/reverse patch
application, schema references, two compiled model fixtures and eleven negative
activation/addressing/topology cases. DTC, dt-schema 2026.09 and its Python
runtime are host-only upstream build tools; no Python enters a tablet payload.
The same SDK compiled the unchanged `at24`, `reset-gpio` and fixed-regulator
AArch64 objects with Clang 23.1.3 and `-Werror` using `board.config`.

No Image, module bundle, RPM, COPR submission, target write, EEPROM read,
power/reset change or stream test is produced by these checks. The active
configuration and patch queue remain unchanged. The combined camera development
branch includes these inactive assets in its Source4 source inventory; previously
published RPMs are unchanged.
See the [board manifest](../../../manifests/camera-board-candidate-20261021.json)
and the canonical UKE-CAM-L002 record in `uke-linux-docs`.
