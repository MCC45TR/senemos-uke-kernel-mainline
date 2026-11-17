# Read-only front gate after native interconnect conversion

17 November 2026. Source33 is prepared for COPR qualification. It is not a
working-camera or successful-boot result. Full9's first boot remained at the
POCO logo for the bounded 180-second observation; SSH never became available.
The preserved full8/B recovery partition was unchanged before that boot.
Physical recovery is pending access to the tablet.

The unchanged front EEPROM helper requires two interconnect argument cells
for the GEM and MC providers, including each request's zero tag. Full9 calls
it inside `uke_abl_transform()`. At that point the inherited providers still
have one argument. `uke_abl_native_select()` later invokes the native display
transform, which calls `uke_bwmon_apply()` and `uke_cpu_bwmon_apply()`. Their
shared `uke_bwmon_mc_tags()` converter expands the existing requests and their
providers together. The front helper therefore rejects the earlier graph
before it can enable an adapter or EEPROM. The normal early refusal path
stops before Linux console initialization. This source finding explains a
possible logo-only failure; no runtime log identifies the exact stopped call.

The correction moves only the front gate to the existing late entry, after
native selection and restoration of capacity in its packed FDT. Audio
configuration and final publication follow it. Controller admission, QUP
quarantine, exact preimage validation, sensor quarantine and fatal refusal of
an incomplete graph remain in place. There are no new board values, bus scans,
firmware requests, power sequences or calibration writes.

The new check extracts the production entry and the actual tag converter.
It reuses the prior synthetic front graph and begins with the inherited
one-argument MC/GEM tuples. It checks the unmodified helper's refusal without
mutation, runs the real tag converter, then exercises the late gate through
the production entry. It also retains the original front-helper refusals,
checks immutable input and unpublished failures, builds with the controller
guard absent, and tests packed-tree capacity, ignored errors and a removed
guard. GCC/Clang and sanitizer runs plus the actual ARM64 caller are required
in COPR. The native-selection callback is controlled: this is not an emulation
of the complete OEM FDT, DPU, I2C, EEPROM or hardware lifecycle.

The source32 recipe and every immutable input remain through a whole-file
inverse. The source33 layer first reconstructs the exact full9 caller from
the qualified source32 preimage, then checks the late correction and its full
inverse. All four previously qualified receiver layers remain present. A
successful source check will still require a cumulative full kernel, signed
DNF delivery, recovery, a real boot and native read-only binding before any
sensor or frame claim.
