# Cliffs camera configuration clocks

5 November2026. Observed12203/source45d8355 fails its first CAMCC AHB gate
verification at0x13318/readback0, before CRM.12101 instead failed its first
GDSC gate at0x132ec. The reordered source alone has not qualified camera access.

Exact Uke OEM GCC5712080a and same-SoC OnePlusfc892483 have identical
gcc-cliffs.c SHA2567d19636bc7e89f4837f5e044436d1bbae854f7ac927289f729867c0290e3e544.
Their probe enables camera AHB0x26004, HF XO0x26028 and SF XO0x2602c before
publishing GCC. The retained139deaba clock patch omits those writes; the native
video layer separately restores only0x32004/0x32030. Reconstructing these exact
retained inputs yields GCC SHA2568d6235495d6176a344989f289470e6187e56a9e3d6a157566200729c0a6c8568.

Linux7.3.1 qcom_cc_clk_hw_get returns NULL for an empty valid GCC slot. The
retained table has no GCC_CAMERA_AHB_CLK entry, although the binding defines10.
Consequently successful consumer clock calls and cached iface=1 do not prove
these unexported configuration registers were enabled. Actual pointer/electrical
state has not been measured; missing GCC setup is a source-supported hypothesis.

The candidate restores only the exact three OEM camera writes with error
propagation before GCC publication. Existing two video writes, voltage ownership,
display/GPU policy and every CAMCC verification/CRM/quarantine gate remain.
No new readback failure in global GCC is introduced: CAMCC still verifies its
own gate and contains failure without exposing cameras. No sensor/EEPROM/capture
DT gate changes, private calibration access or actuator operation are included.

Current upstream SM8650 likewise declares camera AHB/XO critical configuration
gates, but lacks the exact Cliffs SF XO entry; it is shared-IP evidence, not
a replacement board configuration. OEM GPL-2.0-only/Linux Foundation/Qualcomm
attribution is retained in the patch. No donor code or binary is executed.

The actual-probe fixture requires all three camera and two video writes,
11 success/fault paths, the original missing-gate assertion134 and four
register/mask/omission mutants. GCC/Clang ordinary/sanitizer runs and a real
AArch64 GCC object must qualify in COPR. Local checks are syntax/source only.
A following cumulative kernel must retain all qualified peer layers; only
its matching Uke boot can establish whether this corrects the physical fault.
Both full calibrated cameras, rear AF/parking and recovery remain incomplete.

Sources: [Uke OEM GCC](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/blob/5712080a4b0c0b1a879e6d145c601c649ddaddfd/drivers/clk/qcom/gcc-cliffs.c),
[same-SoC GCC](https://github.com/OnePlusOSS/android_kernel_oneplus_sm7675/blob/fc892483f1d61f245924681eb5abd563564d9cba/drivers/clk/qcom/gcc-cliffs.c),
[Linux7.3.1 lookup](https://github.com/gregkh/linux/blob/79a907609d53d5cd645b42c11550d295d43abf99/drivers/clk/qcom/common.c).
