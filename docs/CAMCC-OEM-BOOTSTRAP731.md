# Uke CAMCC transport bootstrap candidate

5 November 2026. The actual12101 boot binds the permanent CAMCC driver but
quarantines it at `critical-gate-verify`, error-5, register0x132ec, readback0.
The cached record marks the gate/readback valid, software proxy/vote masks0x7,
uncertain rails0 and interface enabled; runtime PM is active. These flags do
not measure physical rail levels. CRM is unchecked because the gate failure
precedes its admission. Sensor/capture/EEPROM gates remain off.

Exact GPL-2.0-only Uke OEM source is
[MiCode5712080a](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/blob/5712080a4b0c0b1a879e6d145c601c649ddaddfd/drivers/clk/qcom/camcc-cliffs.c),
file SHA256 `1a76c029c51710af6684a6d4f87e1486c125cd25badfce7b80ba642d820affe6`.
The same-SoC OnePlus file atfc892483f1d61f245924681eb5abd563564d9cba is
byte-identical. Both open DRV_AHB0x13318, DRV_XO0x13314, GDSC0x132ec and
SLEEP0x13308 in that order. The retained native catalog sorted these addresses
and consequently attempted GDSC before either transport gate. Current upstream
Qcom clock-directory inspection finds no camcc-sm7675/cliffs file; its generic
branch/CCF contracts do not specify this chip's bootstrap order.

The candidate restores only the exact OEM order. Addresses, bit0 masks,
checked update/read/verify operations, first-error observations, CRM refusal,
PLL ownership, power votes, quarantine/lifetime and every DT/config admission
gate are unchanged. OEM PLL setup is not moved before CRM admission. No delay,
voltage, reset, retry, generic register reader or undocumented board value is
added. A readback failure must still quarantine the controller.

This is an evidence-based candidate, not a proven physical cause or correction.
The observed zero could have another power, ownership or access cause; it is
not itself proof that the first failing gate depends electrically on AHB/XO.
Successful source/model/object checks cannot establish electrical behavior.

The fixture now imports the actual critical-gate array instead of synthetic
0x700 offsets. Its exact retained12101 array is extracted from sourcebba194e,
with a separate digest. A counterexample provider model discards dependent
requests until AHB/XO are enabled. The actual old array/probe must reproduce
the cached phase/error/register/value and fail readiness134 in that model.
The candidate must pass cold/boot-ON paths and retain active-CRM refusal before
PLL/publication. All existing probe-fault, read-only observation, mutation,
reset/handoff and runtime controls remain required under both compilers and
sanitizers. The dependency model is explicitly hypothetical, not fitted Uke
hardware evidence.

Full qualification still requires one cumulative COPR kernel retaining the
qualified12101/touch/geometry/GMU/memory-v5/DNF union and every additional ready
handoff, signed DNF delivery, and a matching observed boot. The next cached
record must establish whether the failure advances or the controller becomes
ready. Front/rear complete modes, fitted private read-only calibration actually
consumed, rear AF/parking, repeated use and recovery remain incomplete.
