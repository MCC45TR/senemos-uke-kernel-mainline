# Preserve passive protection state and version active observations

11 November 2026. This source candidate corrects a consumer contract gap in
full22 while retaining the demand-driven GET/cache capability.

Original Control217 labels `uke_charge_protection_state` as metadata-only with
no firmware RPC. Full22 refreshes that same endpoint on a cache miss. Native93
tests validate the refresh, but omit the old consumer's passive-read promise.
Normal protection service reads an explicit diagnostic before its cache, but
the manual cold/stale path can still make the metadata claim inaccurate.
The discrepancy involves GETs, not a new hardware write or control lease.

Restore the exact prior passive version-1 state callback. Put active cached
observation at root-only `uke_charge_protection_observe_v2`. Its version-2
fourteen-field record includes whether this read performed GETs. Fresh cache
returns0 for that flag; successful refresh returns1. Errors remain errors and
concurrent epoch changes remain visible in the valid flag. No writer, timer,
worker, retry, fault reset or automatic recovery policy is introduced.

The original diagnostic and standard power_supply paths, fault latches,
thermal/actuator guards and whole cumulative feature/config baseline remain.
This API is observational; neither a valid dry report nor disabled moisture
detection establishes physical protection. The current periodic guard stays
until separate event/action/lifecycle and electrical acceptance.

COPR qualification must extract both real callbacks and assert no RPC from
legacy reads with missing, stale, disconnected or epoch-invalid cache. It must
test versioned provenance, all admitted demand/error cases, root-only mode,
full header/C/document inverse, old standard getters and a real ARM64 object.
Legacy-GET and hidden-provenance mutations must fail. No tablet compilation,
new runtime package or physical acceptance follows from a source receipt.
