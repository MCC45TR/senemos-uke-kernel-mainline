# Cumulative camera candidate, 5 November 2026

The COPR-only producer `packaging/native/copr-cumulative-camera731.sh` retains
the complete production 7.3.1-12101-unstable SRPM, then applies the exact inputs
in `manifests/cumulative-camera731-20261105.json`. Contributor branches are
source references; replacing the complete profile with a partial branch would
lose existing features and is refused. This source factory has not itself
established a successful full kernel or any physical camera result.

The frozen layers include early touch retention, OV08D10 selection geometry,
O82 memory/private-color v5, GMU owned-status acknowledgement, native private
color preparation dependencies, positive SSC transaction IDs, exact CDSP ACTLR,
OEM CAMCC transport-gate ordering and inactive speaker provisioning controls.
The manifest ties every layer to its immutable source and successful component
check. Component source/object checks do not establish final module, signing,
Image, delivery or hardware acceptance.

The production spec retains its existing sections and checks. Additional
preparation checks cover source/config/DT identities and real callback models;
the final check requires the production Image, actual joint native objects,
matching module ABI and signed installed-module copies. The raw configuration
remains the complete12101 input; the original production builder retains
ownership of effective configuration, initramfs and signing transformations.

CAMCC's only production change is the exact OEM relative AHB/XO/GDSC/SLEEP
order. Running12101 first failed critical-gate verification at0x132ec with
readback0 and CRM still unchecked. The transport-dependency model reproduces
that result with the real old array; it does not prove the electrical cause.
No bit verification, PM lifetime, CRM refusal, PLL guard or quarantine is relaxed.
EEPROM access, front GENI, sensor activation and capture-graph gates remain off.

Speaker controls use the qualified controls-only contribution: no protected
graph admission, amplifier-source replacement, protected DT/topology, new stream
format or gain increase. The compile-time admission guard remains in force and
the ceiling remains223. Protected playback requires separate private calibration,
source and physical qualification.

Only the coordinator reserves and submits a fresh unstable revision. All
delivery uses DNF, automatic seamless staging remains enabled and the existing
local rollback preference survives. Stable promotion requires an explicit user
request. The full goal remains both cameras at all supported modes, fitted
private read-only EEPROM calibration consumption, rear autofocus/parking and
repeatable operation with measured recovery and resource release.
