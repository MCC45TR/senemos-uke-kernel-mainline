# Uke USB adapter admission

21 October 2026. Linux 7.2.11 source, host fixtures and separate Fedora Rawhide
AArch64 tablet observations on the running 7.2.11-14 kernel. Release 17 retains
the release-16 hardware policy and introduces no automatic charging profile.

The stock OS3.0.304.0 charger module, SHA-256
`4d5367f0596f8a8f360591101b40630c9c74dde5509f3e3f37223c202ac6f268`,
queries USB adapter property 7 before writing input-current property 5. Its
frontend accepts adapter values 1, 3 and 6. MiCode Uke source
`5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
`drivers/power/supply/qti_battery_charger.c` and `include/linux/power_supply.h`,
identify those values as SDP, CDP and PD. No stock module is redistributed in
this change.

Patch 0098 adds a fresh adapter-7 query to the existing serialized native budget
path. Both the existing wire-6 observation and independent adapter-7 value must
indicate SDP. Unknown adapter data retries only within the existing deadline;
other adapters, transport errors and changed source generations fail closed.
The 500 mA ceiling, source maximum, wet/fault checks and non-Uke paths remain.
Wire 6 keeps its existing bounded legacy interpretation; it is not substituted
for wire 7 or asserted to be an independently qualified OEM enum translation.

The explicit per-CPU system workqueue replaces the deprecated `system_wq`
reference. The current upstream workqueue header already uses that queue for
`schedule_delayed_work()`. Request generations, retry counts and deadlines are
unchanged. Source-derived fixtures exercise the actual worker, protocol callback
and setter, including independent adapter values and a failed adapter query.

The retained root-selector capability and guarded updater dependency are
described in [the capability contract](ROOT-SELECTOR-CAPABILITY.md). This source
does not qualify a physical boot, USB current or suspend transition.

## Observed limit

The tablet's earlier bounded CDC trial recorded successful firmware acknowledgments
for 2, 100, 500 and then 0 mA. After soft unbind, a fresh input-current-limit GET
still returned 500000 microamperes and the battery continued charging. A missed
disconnect callback therefore does not explain that run. An acknowledgement is
not electrical readback. Neither zero-current nor electrical USB suspend is
qualified by this evidence.

The exact stock frontend forwards nonnegative current values without clamping;
negative values become `UINT_MAX`. Local SMB5 voter behavior does not establish
the closed remote firmware's behavior. No negative-current, `UINT_MAX`, raw PMIC
or XM input-suspend workaround is introduced. A zero-endpoint USB function or
FunctionFS interface would not resolve this gate by itself. Automatic activation
remains excluded until reset, configuration-zero, detach and suspend behavior can
be measured with an adequate recovery route. Historical logs and open hardware
risks are retained.
