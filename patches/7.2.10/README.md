# Uke Linux 7.2.10 adaptation

**18 October 2026:** the 47-patch source package includes the native display
profile, standard PMIC ADC units and signed battery power. Patch 0047 preserves
SMP2P input history on ordinary notifications. A physical trace on 7.2.10-4
shows unchanged ADSP ready/handover bits replayed on sleep-state updates; the
extracted-function regression fails before the patch and passes afterward.
The restart handshake and reset on both genuine restart edges are preserved.
This source check does not establish tablet acceptance of release 5.

The following paragraph records the original adaptation baseline; subsequent
native-profile packages have separate build and tablet evidence in the README.

The 40 patches carry the reviewed 7.2.9 adaptation, including the experimental
Adreno 732 catalog and NoC graph, onto the signed upstream 7.2.10 source. Every
patch retains its source attribution and manifest hash. No generic ARM64 fallback
or foreign-device firmware is admitted.

The additional patches connect firmware-display metadata, correct unbound
Adreno removal and preserve SM7675 EPSS operating points for the single-core
Prime domain. The stock-ABL GPU overlay separately supplies nine SM7675
frequency/corner/bandwidth points. Native DPU/DSI work remains an isolated
candidate under `src/display/`; it is not enabled by this release series.

Own-device graphics results remain from the 7.2.9 RAM experiment. A clean source
application, build, signed package check and matched 7.2.10 tablet boot are separate
acceptance steps. Early GPU probing, full DVFS, thermal limits and suspend remain
open; the independent Uke DTS and stock-ABL handoff are different boot paths.
