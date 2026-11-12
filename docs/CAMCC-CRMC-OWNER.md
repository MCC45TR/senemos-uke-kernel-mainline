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

Native108 preserves the complete, byte-identical accepted24 source preparation
and all source inputs. It adopts the complete CRM/CCF backend qualified at
source7a7aa63, plus the declared passive resource changes, before compiling
the actual AArch64 controller and forced CCF/transport adapters with-Werror.
The exact before/after runtime-unit inventory includes preserved catalog,
firmware guard and s2idle source; the existing sleep callbacks and PM ownership
projection remain. Actual resource callbacks run against Linux allocation/lookup
boundaries in GCC/Clang ordinary and address/undefined sanitizer modes.
Existing FDT, CRM mode refusal, registration, handoff and mutation controls
remain. The source factory produces text evidence only; local/tablet builds,
Image/module production and device activation are prohibited.

Native104/11318429 failed after241s: the first resource, FDT and guard controls
passed, but the observation fixture still expected41 boundaries. CRMC added
one lookup before power. Native105 updates that count to42 and shifts the
explicit gate/proxy/resume/PLL failure positions by one. It retains every
assertion; the production driver and firmware refusal are unchanged.

Native105/11318457 failed after265s. All four compiler/sanitizer modes and82
probe fault boundaries passed. The actual object then exposed missing CRM PM
headers: accepted24's packaged profile contained the older provider, despite
the newer qualified sources existing in Git. Replacing only three files was
incomplete. The corrected candidate installs the complete declared closure and preserves the
already packaged s2idle projection. It also repeats the provider/VDD/CCF/PM
controls. No missing include or existing feature is suppressed.

The first native106 source job11318537 failed during source generation: a JavaScript replacement
interpreted the dollar/end-quote in a shell expression and duplicated recipe
text. The single-section guard refused the result; no SRPM or native build was
published. The corrected native106 uses literal replacement callbacks and offline rendering.

Corrected106/11318558 passed prep, complete closure, all resource/DT/refusal,
82-boundary and provider/VDD/CCF/PM controls. The real AArch64 provider compiled
with-Werror. The subsequent import guard expected ioremap_prot, but exact
Linux7.3.3 arch/arm64/include/asm/io.h maps ioremap to __ioremap_prot. The job
failed331s; native107 requires that exact symbol and prints missing imports.
It retains the full object gate and unchanged production source. A separate
SSC fixture counter rename avoids a collision with stdio puts; it changes no
production code or assertions.

Native107/11318571 passed the actual AArch64 provider and forced CRM/CCF
adapter objects, plus all four new SSC streaming callback modes and both old
cache regression controls. It failed342s when the retained pre-heading
quaternion fixture lacked the later heading fanout boundary. Native108 adds
that controlled boundary, preserving every quaternion assertion and the
separate actual heading lifecycle checks. Production source is unchanged.

The source is prepared, not yet qualified by native108. Permanent IRQ ownership,
powered transport attachment, all38 firmware-managed objects, parent snapshots,
inherited AP votes and synchronization remain required before removing the
firmware-enabled refusal. Full cumulative kernel linkage, signed DNF delivery
and both cameras with EEPROM calibration/rear focus remain separate gates.
