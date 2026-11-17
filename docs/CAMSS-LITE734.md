# SM7675 lite VFE register contract

17 November 2026. Full8 has admitted CAMCC and returns it to runtime suspend.
The sensor/CAMSS graph remains inactive. Source review of the next receive
path found two differences between the generic gen3 callbacks and lite860.
These are latent source mismatches; no lite VFE operation or frame was tested.

The exact Uke GPL camera source at
[`699fa15a`](https://github.com/MiCode/vendor_qcom_opensource_camera-kernel/tree/699fa15a98abd40fbb94f3a6fc00f91723d29d35)
selects `vfe_lite88x_bus_hw_info` for `qcom,vfe-lite860`. Its common test-bus
control is 0x1394. The lite86x top register origin is 0x1000, giving native
offset 0x394. The generic callback uses 0x2dc. The same-SoC OnePlus
[`1138e00f`](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm7675/blob/1138e00fee63582a0cc6a53af3286621786827b7/vendor/qcom/opensource/camera-kernel/drivers/cam_isp/isp_hw_mgr/isp_hw/vfe_hw/vfe17x/cam_vfe_lite88x.h)
table is byte-identical to the Uke table. Both retain Qualcomm GPL-2.0-only
attribution. Linux 7.3.4 and the reviewed current upstream gen3 file still
use the generic value.

The lite88x write-master rows also omit frame-drop registers. The OEM
`vfe_bus/cam_vfe_bus_ver3.c` explicitly restricts frame-drop programming to full
IFE. The candidate therefore changes only SM7675 lite test-bus selection and
excludes its two unsupported frame-drop writes. Interrupt subsampling still
requests every frame, and the remaining continuous-capture programming stays
intact. Full VFE and every other platform retain their existing behavior.

Source27 preserves the complete native26 SRPM inputs and recipe. Its new
fixture imports the actual production start/update/stop callbacks and compares
all writes against independently extracted OEM fields for all four lite RDIs,
three strides, two heights and three addresses. Two original before-controls,
four compiler/sanitizer modes, unchanged legacy traces, three semantic mutants
and the actual ARM64 gen3 object are required. No C compilation runs on the
development PC or tablet.

Source27/COPR11340229 passed in 598 seconds. All four compiler/sanitizer modes,
two original before-controls, 31 unchanged legacy trace cases per mode, three
semantic mutants and the actual ARM64 object passed. The signed proof has two
trusted repository signatures. The actual recipe matches the reviewed bytes;
all 24 parent non-spec inputs and the complete old recipe remain intact.
This is source/object qualification; full8 on the tablet has not changed.

Read-only live-DT observations also show that the OEM lite CSID and VFE
descriptions overlap: CSID occupies the first 0xa00 bytes, while the combined
VFE mapping is 0x2800 bytes. A native graph must use the source-defined VFE
origin at +0x1000, rather than mapping both resources at their unit addresses.
The IFE SMMU entry is a separate exact supplier contract. Neither this patch
nor its fixture activates the graph, claims a DMA stream, powers a sensor or
accesses calibration.

The fitted front sensor/address, physical lane map, complete supply lifecycle,
native aggregate graph, completed buffers, private read-only calibration and
rear focus remain open. A qualified source object alone will not reserve a
full kernel release or establish physical camera support.
