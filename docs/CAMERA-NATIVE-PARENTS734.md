# Native camera PLL preparation before ROM decoding

17 November 2026. Full7's cached ROM refusal is client five (CSID), load
`-EINVAL`, with configuration `0x108` and PLL word zero. The mux selects PLL0
main with HID eight. A zero ROM L field makes the resolver read the current
PLL parent. The live parent L value was not recorded, so an unprepared parent
is a hypothesis, not a confirmed hardware cause. The odd-output field fix in
native24 does not explain this source-one selection.

The native constructor currently decodes ROM before configuring local PLLs.
The original GPL Uke provider configures its PLLs before `qcom_cc_really_probe`
populates CRM frequency tables. The candidate moves the existing guarded native
preparation ahead of ROM decoding. The original passive catalog identifies
firmware PLL3–7; neither preparation pass reads or programs those five PLLs.
The remaining PLLs retain their original configuration, FSM refusal, powered
access, inherited-running check and L readback. No frequency, voltage, sensor
address, power sequence or calibration value is added.

Admission still requires checked firmware ownership, both CRM resources,
unpublished clocks, the probe PM reference and all seven maximum proxy votes.
A pure catalog check precedes local programming. The complete powered passive
snapshots and eight RCG preflights remain before IRQ binding and attachment.
The later registration step checks completed admission and powered access;
the original non-firmware path keeps its existing preparation call. Fault
quarantine, inherited-vote synchronization and PM release remain unchanged.

| Source | Contract and license |
|---|---|
| [Uke OEM kernel](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/5712080a4b0c0b1a879e6d145c601c649ddaddfd), `drivers/clk/qcom/camcc-cliffs.c`, `common.c` and `clk-rcg2.c` | PLL preparation before provider registration and CRM table population. Original PLL configurations and firmware-managed classes. GPL-2.0-only; Qualcomm Innovation Center and retained Linux Foundation attribution. |
| [OnePlus SM7675 kernel](https://github.com/OnePlusOSS/android_kernel_oneplus_sm7675/tree/fc892483f1d61f245924681eb5abd563564d9cba), same provider | Same-SoC comparison; no board wiring or new electrical values are transferred. GPL-2.0-only; Qualcomm Innovation Center. |
| [Linux 7.3.4](https://github.com/gregkh/linux/tree/7595a62d45ee1a2297eafa5f2ef5d0a45142d84d), `drivers/clk/qcom/clk-alpha-pll.c` | Native PLL programming and inherited-running handling. GPL-2.0-only with original attribution. |

COPR qualification requires the original constructor to fail the modeled
missing-preparation control under GCC and Clang, four modes each for actual
constructor and PLL/caller bodies, the unchanged independent OEM passive
catalog and its fault/mutation cases, and two complete ARM64 objects. These
framework models do not prove physical ROM admission or a working camera.
Full7 also rolled back because native touch readiness did not meet the boot
health window; that guard remains intact. A later legitimate candidate must
separately qualify boot health, camera power/graph/frames and proper release.

Source25 passed its original-constructor controls and first constructor mode,
then failed because the new direct-PLL framework model had no register map.
Source26 binds that modeled map explicitly. The production overlay is unchanged;
COPR11339884 passed in 508 seconds. All four constructor modes, four actual PLL
and caller modes, four passive modes, four semantic mutants, two original
controls and two complete ARM64 objects passed. The signed receipt and exact
source/archive/recipe identities were independently checked. Physical ROM
admission, front-camera frames and proper hardware release remain open.
