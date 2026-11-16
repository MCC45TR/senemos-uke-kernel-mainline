# Permanent camera IRQ and transport composition

Lesson ID: UKE-CAMERA-OWNER-20261116.

The 16 November POCO Pad X1 observation on kernel7.3.4-4 still stops at
CAMCC `crm-admission -95`, before any sensor/media node. The powered ROM
resolver qualified by native116 was not called from production. Firmware
CRM ownership must remain intact while the missing admission path is built.

This candidate composes the existing permanent CRMC resource, AP SWDRV0
transport and runtime-PM hooks. It accepts only the original controller's
mapping/IRQ, powered unpublished clock catalog and checked firmware mode.
Duplicate, foreign, unpowered, quarantined and published states refuse before
MMIO. Startup AP0 vote words remain unchanged. A failure after transport state
exists retains that state and the permanent mapping; an owned IRQ is masked,
and the controller fault prevents unsafe power withdrawal. No fault is cleared
and no IRQ is freed while ownership is uncertain.

The transport protocol and rising-edge completion IRQ follow exact Uke OEM
`drivers/soc/qcom/crm.c` at
`5712080a4b0c0b1a879e6d145c601c649ddaddfd` (GPL-2.0-only, Qualcomm Innovation
Center copyright). The existing same-SoC OnePlus comparison remains pinned to
`fc892483f1d61f245924681eb5abd563564d9cba`. This layer adds ownership composition,
not new register geometry or a separate firmware writer. The 16 November
bounded upstream/patch-queue search did not identify a ready applicable Uke
CRM binding; that search is not proof that no implementation exists.

The complete existing transport fixture is retained and extended with the
actual owner and PM adapters. New cases cover admission refusals, permanent
IRQ/PM binding, normal idle/rearm, inherited-vote refusal, each of eight IRQ
enable failures and failure after IRQ acquisition but before PM binding.
GCC/Clang plain and sanitizer runs, the unchanged ROM resolver checks and real
AArch64 provider/forced owner/ROM/all38 adapter objects are required in COPR.

The production probe still does not call either the new constructor or ROM
resolver. Firmware admission, all38 attachment, inherited vote snapshot and
synchronized withdrawal must be completed together before activation. Native
front GENI/CCI, fitted sensor, CSIPHY4, CAMSS and completed RAW buffers follow.
This preparation is not a camera frame or physical camera acceptance. Both
cameras, read-only fitted calibration and rear focus remain open.

Native17/11336732 stopped at the whole-provider preimage check, before the
new owner tests. The Git source omitted the inherited prepared s2idle include
and PM selection. Native18 pins the already qualified prepared-provider hash
and inserts only two includes, then verifies its complete inverse. The s2idle
hook and native PM selection remain unchanged; no comparison is weakened.
