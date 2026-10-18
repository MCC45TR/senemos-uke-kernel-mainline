# Full Type-C runtime regression: missing L3B provider admission

Date: 2026-10-18. Environment: retained coordinator kernel24 runtime evidence
and exact kernel25 prepared source. No test, compiler, build or tablet command
was run by this source task. Kernel24 package/initramfs checks passed, but its
tablet display/touch acceptance failed. Kernel23 recovery is separately reported
by the coordinator; a returned DSI connector and active touch service do not
replace the pending user visual confirmation.

## Evidence and source chain

The actual kernel24 FDT SHA256 is
`58773311c1b30f27a39b291260897d79c041a34e0886b8638d37edcc5823891f`.
Its full QMP compatible requests `vdda-phy-supply` from the retained OEM
L3B node, phandle 0x1d6, at
`/soc/rsc@17a00000/drv@2/rpmh-regulator-ldob3/regulator-pmxr2230-l3`.
The parent is `qcom,rpmh-vrm-regulator`, resource `ldob3`. The exact OEM
880000-920000 microvolt constraint and 880000 initial voltage are preserved.
The missing provider is not evidence of a wrong phandle or absent DT node.

The actual prepared `drivers/regulator/qcom-rpmh-regulator-uke.c` rejects
`ldob3` with ENODEV at its project resource allowlist, before command-database
lookup and child registration. It admits neighboring `ldob2`/`ldob4`.
The runtime deferred-probe record specifically names the unregistered L3B
supplier for `88e8000.ssphy`. PMIC altmode waits for its mode switch; DP and
the DWC3 core also defer. Source `drivers/gpu/drm/msm/msm_drv.c`,
`add_mdp_components()`, adds every enabled remote interface, including the new
DP interface, to the required component match. The full master therefore
depends on an additional provider chain even though the internal DSI subtree
is unchanged. The panel-reset provider is unavailable and the touchscreen
service cannot start. This source/runtime chain identifies a concrete provider
omission, not a proven complete post-fix physical root-cause closure. UCSI PPM
timeout and other possible downstream failures need separate returned evidence.

## Source comparison and correction

The workspace donor policy, SM7675 survey, acquisition inventory and component
manifest were consulted. Exact Uke DT `94c84aeb9e517dbde546fc732033c184094c8e57`,
`qcom/cliffs-regulators.dtsi` and `qcom/cliffs-usb.dtsi`, identifies this resource
and its USB consumer. Exact Uke kernel
`5712080a4b0c0b1a879e6d145c601c649ddaddfd` supplies the existing RPMh driver
semantics retained in project patch 0002. The missing allowlist entry is a
project restriction, not a reason to transplant another board's rail values.
Same-SoC/shared-IP comparisons already recorded for the full profile and
upstream regulator/provider/component patterns supply no substitute Uke rail.
The retained GPL-2.0 driver and original notices remain intact.

Patch 0075 adds only exact `ldob3` to the existing allowlist. Command-database
address/slave/type validation, DT voltage/current constraints, locking and all
other refusal paths remain unchanged. No dummy regulator, forced bind,
fw_devlink override, component skip, DT rail substitution or target write is
introduced. Sunlight work moves to a later patch; it is not included here.

## Validation limits and next step

The earlier full-FDT fixture established graph/preservation assertions but did
not execute the regulator provider's resource admission. It did not prove that
the additional DP dependencies could bind or that unchanged DSI nodes would
become an independent display. This missing boundary must remain explicit.

The new actual-admission host fixture extracts the production allowlist and
checks exact accepted resources plus near-miss/unknown refusals. It does not
mock a successful real regulator probe or establish hardware voltage behavior.
It is prepared for the coordinator, not run here. The coordinator must regenerate
checked sources, execute the admission fixture, compile the complete actual
regulator translation unit, inspect the frozen full FDT, then separately record
new package and recoverable tablet probe/DSI/touch results. Preserve the failed
kernel24 image/logs, matched kernel23 recovery tuple and user acceptance limits.

## Preparation-order correction

The coordinator's first fresh preparation rejected the original patch0075
before native-profile application. Its hunk was authored against the fully
prepared provider and contained `mmcx.lvl` context added only by the later
native display queue. This source preparation failed; no fixture, regulator
TU or new package PASS followed from that attempt.

The successor is authored against the coordinator's retained actual pre-native
provider. It inserts only `ldob3` after `ldob17`, before `smpb2`, outside the
later native supply patch's two hunk spans. It does not rewrite that display
patch or bypass checked application. Native preparation retains the actual
post-adaptation/pre-native provider in
`native-generated/rpmh-regulator-before-native.c`; native `%check` executes the
actual-admission fixture against that17-resource stage and the final20-resource
provider separately. The extra native resources must remain refused at the
earlier stage. Both corrected preparation and fixture/TU outcomes require new
coordinator evidence. No test or compiler ran in this source task.
