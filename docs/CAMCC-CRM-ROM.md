# Powered camera ROM parent resolution

15 November 2026. Native source qualification is pending. This layer performs
read-only resolution before provider publication; it does not admit firmware
CRM mode, bind an IRQ, send votes or activate either camera.

The fresh Fedora EXT4 installation runs signed cumulative28. Its existing
CAMCC probe stops at `crm-admission`, error -95, with firmware CRM enabled.
There is no fitted sensor/media graph or completed camera buffer. LIVEPATCH
is disabled and module signatures are mandatory. An unsigned in-memory patch
cannot replace the missing owner protocol.

The resolver uses the exact RCG parent map and unpublished clock descriptors.
An external XO must be the retained 19.2 MHz `bi_tcxo`. For a nonzero ROM L value,
it calculates the selected Lucid PLL with the existing qualified 16-bit alpha
arithmetic and upward kHz rounding. A zero ROM L observes the current PLL
registers and ignores the ROM alpha, following OEM behavior. A selected
postdivider uses its actual powered USER_CTL value and explicit catalog table.
The OEM Fabia/CRM routine uses integer floor division; the generic Linux divider
uses a different rounding rule and is not a substitute here. Unknown encodings,
duplicate source mappings and every I/O error fail without publishing a partial
table. The existing nominal supply ceiling is unchanged.

The eight clients retain their exact PERF banks and CAMNOC's separate VCD8 bank.
All original source inputs, source preparation, camera guards, sleep callbacks,
HWKM and QTEE code remain from cumulative28. The declared runtime delta is one
include plus one new ROM header. Its entry is not called by the production
probe. The native test forces both ROM and all38 managed adapters into real
ARM64 objects without producing an Image or module.

| Evidence | Revision and scope |
| --- | --- |
| [Exact Uke OEM](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/5712080a4b0c0b1a879e6d145c601c649ddaddfd/drivers/clk/qcom) | `clk-rcg2.c`, `clk-alpha-pll.c`, `camcc-cliffs.c`; unchanged copies and SHA-256 in the manifest |
| [Same-SoC OnePlus](https://github.com/OnePlusOSS/android_kernel_oneplus_sm7675/blob/fc892483f1d61f245924681eb5abd563564d9cba/drivers/clk/qcom/clk-rcg2.c) | Same CRMC parent/L/alpha callback structure; no board data imported |
| [Palawan/Lamma](https://codeberg.org/palawan-mainline/linux/src/commit/0d9f7fdf720ae9f4ecfbee4fadaf1e3b5c442e95/drivers/clk/qcom/camcc-palawan.c) | Shared register/catalog background; direct RCG programming is insufficient for Uke's active firmware CRM |

PC checks are source syntax and data/hash checks only. COPR qualification must
run GCC and Clang with ordinary and address/undefined sanitizer modes, all
eight banks, 112 ROM-read failures, parent-register failures, exact postdivider
rounding and power/publication/identity refusals. Actual provider and forced
adapter ARM64 objects must pass `-Werror`. These are pending, not passing claims.
Permanent transport/IRQ ownership, inherited AP0 votes and synchronized withdrawal
still precede active provider admission. Native front CCI/sensor/CSIPHY4/CAMSS,
completed RAW buffers, controls, supported modes and physical recovery remain
required. Both-camera and private read-only calibration goals stay open.

Native115/source11331331 stopped before SRPM creation: its phase classifier
rejected cumulative28's inherited `make olddefconfig` preparation. Native116
pins the entire 58-line source phase by SHA-256 and permits only that exact
configuration-preparation command. Production Image/module commands remain
outside the source phase. No native test or hardware success came from115.
