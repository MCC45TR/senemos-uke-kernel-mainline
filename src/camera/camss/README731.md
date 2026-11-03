# Uke CSIPHY 2.2.1 programming prerequisite

3 November 2026. The D-PHY helper is inactive source. The COPR producer compiles
it with the complete original native CSIPHY source as an unlinked object and
executes isolated MMIO/time boundary fixtures. No compatible, platform driver,
CAMSS resource profile, DT activation, controller binding or capture is added.

The 103-entry table retains the exact Uke OEM order, values, delay units and
Qualcomm GPL-2.0-only attribution. Common control0x101c uses0x7a; reset stays
asserted until mission programming completes and exits to2 for noncombo D-PHY.
Disabling skew calibration writes zero to the16 named registers, as the OEM
code does. The stable generic callback skips them instead; substituting this
table alone would preserve different values after the initial reset sequence.
Native frame completion uses CSID, so this helper keeps all11 PHY IRQ masks
zero instead of adopting OEM interrupt enables.

The helper validates lane positions/duplicates, clock rate and settle arithmetic
before MMIO. It admits a400MHz timer and positive link frequencies up to750MHz
with an encodable settle count. This source range includes the reviewed stable
OV08D10 360/720MHz and OV13B10 560MHz candidates; fitted topology, all actual
modes and electrical timing remain unqualified. C-PHY, combo mode and additional
profiles remain outside this helper; the full camera goal is unchanged.

The caller must establish exclusive powered PHY/IRQ/clock/rail ownership and
propagate admission errors before using this helper. A complete native caller
is not yet connected. Its raw MMIO/time interface does not detect electrical
failures or establish safe DMA, concurrent graph use or power teardown. Existing
source clocks and a passed object/fixture are not physical camera acceptance.

Source: MiCode/vendor_qcom_opensource_camera-kernel at
699fa15a98abd40fbb94f3a6fc00f91723d29d35,
`drivers/cam_sensor_module/cam_csiphy/include/cam_csiphy_2_2_1_hwreg.h`
SHA-2565d5bc215b97bdec610ec4698c49a297c0ccdfab211fb4c3380b8555ef63ca99a,
and `cam_csiphy_core.c`
SHA-25611f6a85cfb70ca7edbbe3a41c395fbe525c1db822f881171c527de652de78cb9.
The ordinary/sanitized differential fixture imports the independent pinned OEM
arrays and actual common/lane programming bodies, with MMIO/time modeled.
It compares512 lane-order/rate/skew cases plus invalid/timing refusals. A real
stable generic callback is the zero-skew negative comparison. The stable7.3.1
native source/settle helper is pinned independently. Neither donor scripts nor
Android libraries execute; no private profile or calibration bytes enter COPR.

The oracle imports parameter bit masks and the exact register-entry type from
the same pinned `cam_csiphy_dev.h` (SHA-256
efef1af717f54ad458a1db00c989fcaa4fdd775a8572d49ea8924cfad0ccee82).
Its `OEM_CSIPHY_` names keep those masks separate from native CAMSS enum values.
Native candidate tags are translated by semantic name; OEM numeric masks are
not substituted into the native callback contract. Initial1208 stops before
kernel compilation on a missing combo-tag fixture definition; no new PHY test
pass or device result is claimed for that build.
