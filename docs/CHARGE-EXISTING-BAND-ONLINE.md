# Existing charge band: explicit above-limit reapplication

11 November 2026. Source preparation; not built, installed or electrically
qualified. Keep the cumulative full18 kernel, its accepted rollback and all
other hardware features until the complete delivery is qualified.

The charge controller reports an enabled70/80 band while the observed tablet
is above80. A bounded capture includes a positive battery-current sample;
`Full` status and a successful settings GET are not proof of charge cutoff.
The operator reports that an earlier kernel held near84. The installed
full4 and full18 battery modules have identical code, data and relocation
sections outside module/build identity. This does not exclude a kernel,
DSP-lifecycle, source-contract or firmware-state regression.

The exact Uke OEM kernel5712080a4b0c0b1a879e6d145c601c649ddaddfd,
`drivers/power/supply/qti_battery_charger.c`, SHA256
88180b5a5c14f500bd818070e6bd9760e6eb91d06e734c01592e3d07c969d6df,
separates feature permission from `battery_psy_set_charge_threshold()`.
The latter sends opcode0x48 with enable,target and hysteresis delta. Its
runtime setter has no input-off requirement. Same-SoC OnePlus Nord4 source
fc892483f1d61f245924681eb5abd563564d9cba uses the same split; file SHA256
1ff5663cf0145fbbd25f1c65c8781ec63252d76f280f83448f8a93b7c8d0dc59.
Both are unchanged references. Their opaque response handling supplies no
electrical cutoff, battery-bypass, limiter or general safety qualification.
No OEM implementation is copied into the patch.

The existing fixed diagnostic can apply70/80 only with input disconnected.
Keep that operation unchanged. A separate root-only request,
`uke_charge_apply_existing_cap_online`, accepts only literal1 and requires:

- The already-enabled exact70/80 band, a present battery and reported Good health.
- Online external input and a fresh reported SOC in80..100.
- No latched moisture/protection fault, active competing control or uncertain
  earlier fixed request.
- The same healthy firmware/source/driver generation within the existing
  five-second transaction window.

It sends the existing fixed `{enable=1,target=80,delta=10}` request once.
There is no arbitrary target, feature-enable/disable, FCC, CV, input-current,
input-suspend, XM or PD selector. The two fixed operations share attempt
quarantine. Timeout, malformed response or readback failure never causes
replay or undo. Matching same-epoch GETs and return0 still mean only request
receipt plus configuration readback; physical effect remains unknown.

This is an explicit operation, not a boot policy, periodic guard or new
daemon/RPM. It does not automatically reapply a target after reboot, DSP
restart or reconnect. The existing Control bridge and standard threshold
transition need separate integration after the fitted behavior is measured.

Before delivery, extract and test the actual dispatcher/wrappers with
GCC/Clang and sanitizers, including below-limit, wrong-target, source-change,
fault, privilege, error and no-replay cases. Compile the actual cumulative
ARM64 battery object, retain every full18 source/config/DT/audio gate, verify
signed packages and normal DNF/A-B recovery, then measure battery current,
charge counter, status and voltage through a controlled request. Do not mark
70/80 cutoff, autonomous restart or physical protection accepted from a build.
