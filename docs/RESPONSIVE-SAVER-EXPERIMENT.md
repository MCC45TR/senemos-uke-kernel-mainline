# Responsive low-power profile experiment

The cumulative provider currently sets every CPU maximum to its hardware
minimum in `low-power`. Schedutil then cannot raise frequency for interactive
work. All six CPU governors are already available on the inspected device;
adding a governor alone does not remove this QoS ceiling.

This small source experiment removes only the profile-owned CPU ceiling.
Schedutil/EAS, the performance floor, independent user/thermal constraints,
the existing 500 MHz GPU preference and transactional rollback remain.
It does not reproduce OEM WALT or scene-specific policy and makes no energy,
thermal, latency or user-comfort claim.

The experiment is checked after the exact cumulative source52 recipe, retaining
all earlier checks, then recompiles the actual AArch64 provider object. The
new source receipt is not a production/full-build authorization. The accepted
source52/full10 baseline and current boot slots stay unchanged. Compare energy,
responsiveness, thermal behavior and profile transitions before integrating
this change into a delivered default kernel.

Research inputs:

- Exact Uke/SM7675 CPU frequency tables and native `freq_qos` constraints.
- MiCode Uke kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd`.
- [Common vendor snapshot](https://github.com/Xiaomi-Pad-7-Pro-Resources/android_vendor_xiaomi_sm8635-common/tree/fbbb8cb54a81f47a6f657d95675f00320db9aab0)
  `fbbb8cb54a81f47a6f657d95675f00320db9aab0`,
  `targetconfig.xml` blob `980867c8764f4e35cf3ddfd4fe5b4fd8b992b29e`:
  Cliffs has 3+4+1 cores and uses schedutil in the downstream configuration.
- `PSMPowerOptFeature.xml` blob `67c45c36b53211094cecfeb1b5628f8bc2395be2`:
  downstream power saving combines load/scene decisions instead of the native
  provider's all-cluster minimum-frequency ceiling. This proprietary reference
  is not copied or executed. Its policy is not portable as upstream register,
  scheduler, thermal or application overrides.
- Apache-2.0 common power extension
  `bbfd9f95cbe244097daae8b9592d11c036bb5aeb3` only implements double-tap wake;
  it supplies no transferable low-power frequency limits.

Original Fedora power-profiles-daemon remains the userspace interface. No new
daemon, polling loop, runtime RPM or desktop fork is introduced. The earlier
governor/energy and all other external-tracker goals remain open.
