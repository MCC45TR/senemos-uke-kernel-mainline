# Demand-scoped SM7675 PHY supplies

17 November 2026. Source29 prepares native consumer voltage requests for the
Uke receive path. Qualification is pending after correcting a fixture counter
that collided with the standard C library. The power candidate is unchanged.
Accepted full8/B remains installed;
the sensor, bus and CAMSS graph remain inactive.

The selected device tree limits CSI L2B to 880000–912000 microvolts, while the
shared regulator provider permits up to 950000. Display, USB, DP and UFS also
use this supply. The native PHY previously enabled it without its own voltage
request. The new resource fields express the observed CSI limits and loads;
they do not change the shared provider's constraints.

First-on acquires native PM ownership, establishes clock rates and requests
each consumer voltage/load before enabling its rails and clocks. Last-off
quiesces its IRQ and clocks, disables both rail consumers, then removes only
its voltage/load requests and releases PM. Healthy idle has no camera voltage
vote or extra PM reference. No background worker or polling is added.

Partial power changes have no assumed rollback postcondition. A failed supply
operation or cached CAMCC fault returns an error and retains the necessary
ownership until reboot. Manually acquired regulator/device references and
their allocation survive fault cleanup. IRQ delivery is stopped. This does
not force a shared voltage or retry an uncertain operation.

The typed CAMCC status function reads cached admission/fault fields only. It
requires native readiness, without waiting for the later CCF sync-state
callback: waiting for sync-state from a probing consumer would deadlock that
handoff. A separate SM7675 platform descriptor suppresses user bind/unbind;
the original platform descriptor and legacy PHY power bodies are preserved.
SM7675 additionally refuses module ownership or dynamic DT storage. The source
check retains the current module configuration to compile the cumulative
objects; a future runtime profile needs separate built-in linkage validation.

The planned COPR check runs actual power, dispatch and provider-status
functions under GCC/Clang with and without ASan/UBSan. It includes original
before-controls, every fallible call in a healthy first-on/last-off sequence,
shared-consumer conflict, clock teardown fault, supplier deferral, clean and
fault cleanup, five semantic mutants and unchanged legacy traces. Three real
ARM64 kernel objects provide independent integration coverage. Framework
models do not establish an electrical result or a physical camera frame.

Sources are the pinned Uke GPL kernel/camera repositories and Linux 7.3.4
listed in [the source manifest](../manifests/phy-power734-20261117.json).
Voltage/load facts come from read-only selected DT observations; no code is
copied from the camera overlay with unidentified license. Sensor identity,
address, power sequence, lanes, the camera interconnect route and rear PHY0
variant remain separate admission work. Both cameras, private read-only fitted
calibration and rear focus remain in scope.
