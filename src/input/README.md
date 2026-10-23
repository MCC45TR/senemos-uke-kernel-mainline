# Uke THP transport candidate

23 October 2026: release 21 reached the Uke login screen in boot A, but its
touch provider did not autoload. Manual loading exposed a first SPI transfer
reported as 0/3 bytes. Release 22 adds the SPI module alias and corrects the
GENI GPI callback's premature successful message status, retaining the exact
length guard. Host callback controls distinguish successful completion, DMA
failure and residue; cold boot and physical contacts remain separate tests.

23 October 2026. The candidate captures complete 5432-byte Uke normal-firmware
packets as root-only V4L2 MET8 metadata. It retains counter, scan type and signed
raw nodes; contact processing remains in the matching calibrated C++ client.
The hardware-support source supplies `uke-sensors/src/touch-capture.cpp`.

`sm7675-uke-thp.dtsi` is an explicit candidate binding for the existing Uke
SPI leaf. It links the native O82 panel, existing GPIO26 input and GPIO54 rising
IRQ. It introduces no new rail, reset, SPI-clock or pinctrl values. The host
contract applied it to a retained running release 14 FDT, checked those existing
OEM properties and resolved the actual panel/GPIO phandles. Other properties
of the touch leaf and the input file were preserved. That is an offline DT
result, not a tablet driver or contact result.

```sh
make test-touch-dt kernel_source=/path/to/prepared/linux \
    running_fdt=/path/to/private/running.dtb dt_output=build/touch-dt
```

The output directory must be new. The source reference is the exact Uke
normal-firmware protocol; OnePlus Pad 2 and Lenovo coordinate-firmware drivers
are shared-controller lifecycle comparisons, not packet replacements. No donor
board values or proprietary calibration are included.

Release 7.2.12-18 selects the driver and overlay. Its module RPM also owns the
matching C++ processor under `/usr/lib/modules/<release>/uke/`; the boot manifest
records its digest. Activation requires the updater's client admission and the
hardware-support dispatch capability. The private firmware alias
`novatek/uke/nt36532-normal.bin` resolves to the separately retained private RPM.
No private firmware or calibration is included in the kernel package.

Suspend quiesces the IRQ and workers before invalidating completed buffers with
the standard [VB2 suspend helper](https://docs.kernel.org/driver-api/media/v4l2-videobuf2.html#c.vb2_discard_done).
Recoverable tablet/contact validation remains required. Gesture wake is not
implemented.
