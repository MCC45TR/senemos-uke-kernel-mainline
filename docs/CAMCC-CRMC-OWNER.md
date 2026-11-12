# Permanent passive CRMC ownership

This extends the qualified [DT resource conversion](CAMCC-CRM-DT-RESOURCES.md)
over accepted7.3.3-24-unstable/source6719b05e/COPR11309609. Native103 at
11318374 qualified the actual FDT converter; it did not activate a transport.

The controller now reserves and maps the exact OEM CRMC window at0xadda000,
size0x2000, and resolves its named CRM IRQ after the permanent CC_BASE and
configuration owners exist. It does not read or write CRMC, request the IRQ,
send votes or replace the firmware-enabled refusal. A failed lookup/deferred
IRQ returns before allocation. A failed mapping releases its reservation.
Clean unpublished probe failures unwind CRMC before configuration and CC_BASE.
Busy, faulted, foreign-owner or attached-transport state retains the mapping.

This follows the existing permanent built-in CAMCC contract. The upstream
[devres documentation](https://docs.kernel.org/driver-api/driver-model/devres.html)
explains that managed resources are released on driver detach; this provider
must retain state after uncertain partial publication. Exact register/IRQ
topology remains attributed to Uke DT94c84aeb and kernel5712080a, with the
same-SoC comparison pinned in the existing source review. No donor file changed.

Native105 preserves the complete, byte-identical accepted24 source preparation
and all source inputs. It overlays only the declared driver, registration and
new passive resource header before compiling the actual AArch64 controller
with-Werror. Actual resource callbacks run against Linux allocation/lookup
boundaries in GCC/Clang ordinary and address/undefined sanitizer modes.
Existing FDT, CRM mode refusal, registration, handoff and mutation controls
remain. The source factory produces text evidence only; local/tablet builds,
Image/module production and device activation are prohibited.

Native104/11318429 failed after241s: the first resource, FDT and guard controls
passed, but the observation fixture still expected41 boundaries. CRMC added
one lookup before power. Native105 updates that count to42 and shifts the
explicit gate/proxy/resume/PLL failure positions by one. It retains every
assertion; the production driver and firmware refusal are unchanged.

The source is prepared, not yet qualified by native105. Permanent IRQ ownership,
powered transport attachment, all38 firmware-managed objects, parent snapshots,
inherited AP votes and synchronization remain required before removing the
firmware-enabled refusal. Full cumulative kernel linkage, signed DNF delivery
and both cameras with EEPROM calibration/rear focus remain separate gates.
