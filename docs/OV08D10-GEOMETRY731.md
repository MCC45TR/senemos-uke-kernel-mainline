# OV08D10 geometry on the retained 7.3.1 API

5 November 2026. The proposed patch reports native pixel-array and analogue
crop coordinates for the three existing modes. No sensor register, rate,
power sequence, configuration or DT admission changes. Physical front-camera,
fitted calibration and full-mode acceptance remain incomplete.

Geometry is adapted from Max Bretschneider's GPL-2.0
[authored v2 4/4](https://lists.openwall.net/linux-kernel/2026/10/23/2170).
Its preceding active-state/cache changes target a newer four-argument pad API.
This backport retains the original private mutex, three-argument callbacks,
ACTIVE mode cache and per-file TRY state. TRY format and crop initialize on
open and change together; ACTIVE crop is read from the current mode under the
same mutex as format changes. Read-only selection cannot change controls.

| Geometry | Native sensor coordinates |
|---|---|
| Native array | 3288x2476 at0,0 |
| Active bounds/default | 3280x2464 at4,8 |
| 3280x2460 output | 3280x2460 crop at4,8 |
| 3264x2448 output | 3264x2448 crop at12,16 |
| 1632x1224 output | 3264x2448 crop at12,16,2x2 binning |

Exact retained7.3.1 source SHA256 is
`dea565800781f428397acd082c4cb76af2aee63eb51dc006b02000b13777a1ad`.
With the already qualified probe and exposure guards, the preimage is
`96aad491915796d54e2a8cd20c90a9a8c4e58515c64f7ad4d5faae39caa4d31c`;
the proposed geometry output is
`df7ce54741d6a08c09ff607b86ce33c2057bb05c52b4d1a21d98b5be3395700e`.
Current upstream file history still points to
`7eef49c164615a6460dc49448b67444a65997017`; its newer pad API does not implement
this selection hook. The exact authored geometry is source evidence, not a
public fitted-module datasheet, EEPROM schema or proof of coordinate-correct
calibration consumption on Uke. OEM ROM module names do not identify the
physically fitted part. No adjacent-board sensor programming is transplanted.

COPR qualification must import the actual prepared data/callbacks, reproduce
the original absent hook, cover all three modes, four Bayer flips and two
independent TRY files, preserve ACTIVE controls and refuse invalid selections.
The wrong analogue binning rectangle, lost TRY update and wrong ACTIVE-state
source must each fail independently. GCC/Clang ordinary and sanitizers plus
the actual AArch64 sensor object are separate checks. No fixture is installed
on the tablet and no kernel revision is reserved by a source check. A following
single cumulative kernel must preserve all12101 features and the qualified
touch layer before this change can be delivered through signed DNF packages.
