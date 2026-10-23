# Uke THP transport candidate

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

Release preparation does not select this driver or candidate overlay. Paired
kernel/DT packaging, the private firmware path `novatek/uke/nt36532-normal.bin`,
contact-service migration and recoverable tablet validation remain required
before retiring the current touchscreen RPM. Gesture wake is not implemented.
