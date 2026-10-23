# CPU idle governor comparison

24 October 2026. Uke kernel 7.2.12-22 exposes PSCI idle states and uses menu.
The optional [TEO fragment](../configs/experiments/teo.config) adds the upstream
governor while retaining menu and all platform state descriptions. It is not
included in production native.config or the package build.

Uke OEM and same-SoC GKI configuration enable both governors. No vendor governor
or idle-state parameter is copied. Linux 7.2.12 rates menu at 20 and TEO at 19;
its registration path chooses the higher rating when no governor override is
present. A matched laboratory build must still verify the actual control
governor before any runtime comparison.

Run the host configuration check against the pinned, prepared Linux source:

~~~sh
bash tests/teo-config-contract.sh /path/to/prepared/linux-7.2.12
~~~

The check first requires the resolved control to match the committed native
configuration byte for byte. Missing Uke symbols or a different source/compiler
context fail before comparison. It then permits only the TEO symbol
to differ. MENU, PSCI, MGLRU, zram, THP and the original clock, regulator and
power-domain behavior remain part of the unchanged control.

After a fresh matched RPM and recoverable boot are qualified, use the standard
CPUIdle sysfs interface for a bounded menu, TEO, menu comparison. Keep display
mode/VRR policy, workload, thermal controls, CPU/GPU policy and memory settings
fixed. Verify the initial governor and restore it after the trial. Record
declared state timing, completed entries, above/below/rejected counters,
accounted residency, IRQ activity, interaction latency and energy.

Software idle accounting is not a hardware energy measurement. Entries that
cross sample boundaries can distort short-window time fractions. IRQ counts
are not necessarily wakeups, and a rejected entry does not identify its cause.
Clock-summary Y values may be assumed for nongating clocks; a zero software
reference count alone does not establish that a resource is safe to disable.
Retire each ignore-unused workaround only after its suppliers and recovery
behavior have been tested independently.
