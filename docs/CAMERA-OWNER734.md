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

Native18/11336815 passed source composition and the retained native checks,
then stopped while compiling the owner fixture. Its empty Linux errno stub
shadowed the system errno constants through glibc. Native19 removes only that
stub and keeps the system errno header; production camera code is unchanged.
The owner fixtures and actual ARM64 composition remain unqualified.

The next source qualification also checks a read-only AP SWDRV0 startup
snapshot. It covers exactly the seven PERF and one CAMNOC bandwidth voter
from the OEM register map. All tables and register bounds are admitted before
reads; two vote observations and three status observations must agree.
Unknown bits, nonzero bandwidth without VALID, unsupported level/quantization,
pending completion and read errors refuse without publishing partial output.
This detects observed changes; it does not prove an atomic firmware ownership
transfer. No votes are adopted or withdrawn and production probe is unchanged.
The fixture injects each of72 read failures,24 vote changes and24 pending
status positions, plus two semantic mutants, in four native compiler modes.

The17 November activation review found a source-composition error before any
probe activation: AP SWDRV0 registers use the primary CRM window, while the
frequency ROM uses the separate CRMC window. Exact OEM crm.c assigns each
software driver's base to crm->base and maps the CRMC manager separately.
The constructor now passes the primary owned CRM mapping to the transport.
The owner fixture uses two distinct address windows and rejects a wrong-map
mutant. Earlier owner19/20 checks shared a single modeled window and did not
cover this distinction; their other results do not establish hardware admission.
No wrong-window access was performed on the tablet.

The inherited-vote adapter records Linux software requests separately from the
maximum checked boot vote for each of the eight AP0 clients. Until provider
synchronization, a new request cannot withdraw that minimum. The permanent
caller must hold the maximum admitted voltage proxy and controller power.
Synchronization serializes with consumer callbacks, withdraws only minima
above the latest software request and performs no redundant IRQ transaction.
A partial failure stays latched and requires the caller to retain power/proxy.
No CCF software rate is inferred from the firmware's aggregate rate. This
adapter still needs the complete production admission and sync-state caller;
these source checks do not activate firmware CRM or a sensor.

## Complete admission candidate, 17 November

The next source candidate calls the composed admission path from the normal
probe only after the existing firmware-mode observation refuses direct clock
programming. It requires the original powered resources, all maximum supply
proxy votes and the unpublished catalog. The eight ROM tables must fit the
existing characterized voltage map. All30 passive clocks and eight software
voters are validated before the permanent IRQ is enabled. Primary CRM startup
votes are read separately from the CRMC ROM, decoded, then checked again under
the permanent transport lock before callbacks are attached. Observed changes
refuse admission; two reads do not establish an atomic firmware transaction.

The maximum inherited AP0 votes remain floors until successful CCF boot-hold
synchronization. Only then are the floors withdrawn, before genpd, voltage
proxy and probe-PM references can be released. Partial withdrawal errors stay
latched. A first transport fault also quarantines the controller immediately,
including an unexpected IRQ without a waiting CCF caller. Quarantine retains
rails, mappings and the permanent IRQ; no live retry or fault clearing is added.

The runtime-resume candidate checks the actual ROM words captured during
admission while the IRQ remains quiesced, refreshes passive observations, then
rearms the transport. Unknown state or a failed refresh retains power. Physical
ROM content, voltage-table coverage and runtime/suspend behavior still require
the matched full kernel on the tablet; the qualified host model is not that
evidence.

Source22 adds four compiler modes for the actual constructor with framework
boundaries modeled, four modes for the actual registration/sync callers and
real ARM64 code generation for the complete provider and forced admission,
resume and sync functions. Existing owner, ROM, startup, floor and historical
native tests remain. Exact whole-file preimages, postimages and an inverse
patch preserve the prepared provider's s2idle integration; the Git provider
alone remains insufficient to reconstruct that cumulative source.

This is a source qualification candidate. No sensor is enabled by these
fixtures. The running kernel5 still correctly refuses at `crm-admission -95`;
front GENI, OV08D10, CSIPHY4, CAMSS, completed RAW buffers, fitted read-only
calibration and the rear camera/focus remain open.
