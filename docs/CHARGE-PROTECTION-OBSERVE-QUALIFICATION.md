# Versioned protection observation qualification

11 November 2026. [COPR11305076](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11305076/)
qualifies source `a204f9a9f62e7053e47f11f3ce133d195966c13e` against the actual full22
SRPM. The source check took368seconds. The signed text-only receipt has SHA256
`669e1a4bd552607ad78931cb7063a879d7e68b38194a8e79e885c68111f5a468`.

The legacy callback exactly matches the passive full21 implementation. Four
GCC/Clang normal and sanitizer configurations pass passive legacy13-field and
root-only version2 14-field observations, refresh provenance, stale/cache
boundaries, epoch races, transport errors, partial reads and quiescent states.
Restoring legacy GETs and hiding refresh provenance each fail the regression
fixture. All three changed source files reverse to the exact full22 baseline;
the real AArch64 battery object compiles. Standard threshold fixtures retain
both control-config paths.

All768 parent composition fields and the production configuration remain
unchanged. The original fault, thermal, actuator and request guards are retained.
No SET, timer, worker, service or runtime package is added. The periodic guard
is not retired and gain remains223.

This is source and object qualification. The tablet still runs kernel22; no
following full kernel is reserved by this record. Full Image/module/DT/RPM,
normal DNF and A/B delivery, actual boot and physical70/80 cutoff, full-charge
termination and fault response remain separate gates.
