# Camera ROM odd postdivider field

17 November 2026. This source candidate fills a catalog coverage gap; it does
not yet establish the cause of the tablet's full6 `crm-rom -EINVAL` refusal.
The diagnostic full7 boot is still pending.

The original Uke catalog contains the PLL0 odd output with `post_div_shift=14`,
width four and encoding two for division by three. Its even output uses shift
ten, width four and encoding one for division by two. Both appear as possible
parents of managed camera muxes. The current ROM resolver rejects every shift
except ten, so it refuses a valid odd parent before reading the output field.

The candidate admits exactly shifts ten and fourteen from the already checked,
unpublished original catalog. It keeps the native parent-class check, width,
unique divisor lookup, powered read, original PLL arithmetic, integer division,
frequency/voltage limits and firmware ownership. No register or vote is written.
Unknown shifts and encodings continue to refuse without publishing a rate.

| Source | Contract and license |
|---|---|
| [Uke OEM kernel](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/5712080a4b0c0b1a879e6d145c601c649ddaddfd), `drivers/clk/qcom/camcc-cliffs.c` and `clk-alpha-pll.c` | Exact original odd/even fields and integer-floor calculation. GPL-2.0-only, Qualcomm Innovation Center and retained Linux Foundation attribution. |
| [OnePlus SM7675 kernel](https://github.com/OnePlusOSS/android_kernel_oneplus_sm7675/tree/fc892483f1d61f245924681eb5abd563564d9cba), `drivers/clk/qcom/camcc-cliffs.c` | Independent same-SoC comparison contains the same shift-fourteen odd output. GPL-2.0-only, Qualcomm Innovation Center. No board wiring is transferred. |
| [Linux 7.3.4](https://github.com/gregkh/linux/tree/7595a62d45ee1a2297eafa5f2ef5d0a45142d84d), `drivers/clk/qcom/clk-alpha-pll.c` | Generic postdivider reads use the catalog's `post_div_shift`. GPL-2.0-only with the file's original attribution. |

The new fixture imports the actual prepared even/odd tables and field shifts.
It decodes different fields from the same modeled USER_CTL word, retains all
eight bank and 112 read-failure cases, and refuses unknown shifts. The original
resolver must fail the actual odd case under both GCC and Clang. Four normal/
sanitizer modes and two complete ARM64 objects remain required in COPR.
This changes no fitted sensor address, lane map, power sequence or calibration.
Physical ROM selection and the complete camera pipeline remain unqualified.
