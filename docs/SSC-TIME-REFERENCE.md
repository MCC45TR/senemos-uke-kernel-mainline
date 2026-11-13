# On-demand SSC time reference

The accepted25 driver reports IIO host-arrival timestamps. Exact Qualcomm and
OEM/current upstream research is recorded in
[the clock/frame review](SSC-HARDWARE-TIME-REVIEW.md). Fitted SSC counter-domain
agreement remains unmeasured. This source layer adds the missing diagnostic
without changing data delivery or inferring a conversion.

The controller's root0400 `ssc_time_reference` attribute takes one coherent
cache snapshot under its existing state lock. A current controller also reads
CNTFRQ and the kernel's architectural counter bracketed by CLOCK_BOOTTIME.
Formatting happens after unlocking. No per-report work, sensor request, timer,
stream owner, buffering/rate change or hardware wakeup is added. An attribute
read remains demand-driven and never creates a firmware transaction.

The output always says admitted=0. A valid cache can be old or inactive; the
current query bracket is not its acquisition timestamp. Disconnected, paused,
wrong-generation, unavailable/error metadata and empty caches do not expose
stale tick fields. Frequency0, counter0 or reversed brackets leave the host
reference unavailable. No sample values, SUID, client IDs or calibration data
are exported. The kernel counter may use its selected virtual/physical access;
the diagnostic does not assert equality with Qualcomm's fitted timestamp epoch.

Every existing driver byte outside three declared insertions is preserved by
the patch's whole-file inverse. Native109 is designed to retain the complete
native108 preparation and tests, then apply this layer and test the actual new
callback in eight compiler/config/sanitizer modes plus six mutant refusals.
The actual resulting AArch64 SSC object must compile with-Werror, keep the new
attribute symbol/marker and use the exported architectural-counter interface.
No Image, runtime package, installation or clock/frame acceptance follows from
that source check. It does not open Motion1 production admission.

After cumulative delivery, a finite admitted IIO stream and root snapshots can
establish whether firmware ticks share the reported domain. That correlation,
bounded uncertainty, acquisition-time conversion, generation/suspend behavior,
gravity frame and original Fedora SensorProxy parity remain separate gates.
See the [ABI](../src/sensors/sysfs-driver-uke-ssc-time-reference) and
[source manifest](../manifests/ssc-time-reference-20261113.json).
