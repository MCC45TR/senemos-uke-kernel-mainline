# Uke Linux 7.2.10 adaptation

The 37 patches carry the reviewed 7.2.9 adaptation, including the experimental
Adreno 732 catalog and NoC graph, onto the signed upstream 7.2.10 source. Every
patch retains its source attribution and manifest hash. No generic ARM64 fallback
or foreign-device firmware is admitted.

Own-device graphics results remain from the 7.2.9 RAM experiment. A clean source
application, build, signed package check and matched 7.2.10 tablet boot are separate
acceptance steps. Early GPU probing, full DVFS, thermal limits and suspend remain
open; the independent Uke DTS and stock-ABL handoff are different boot paths.
