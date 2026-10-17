# O82 video AVR experiment

18 October 2026. This source path is an **unqualified receiver experiment**
for Uke SM7675, the native OEM PB/42 profile, dual DSI and DSC. It defaults to
off. There is no qualified VRR range or `vrr_capable` advertisement.

The existing seven fixed modes and panel command sequences are retained.
The CRTC's standard atomic `VRR_ENABLED` property controls the experiment.
Unsupported active modes and topology are rejected during atomic checking.
That stage does not write hardware. A read-only MSM module parameter,
`o82_vrr_test_min_hz`, supplies the experimental lower bound. Zero disables
the path; the current 32-line development bound admits only the value 119
with the exact OEM 120 Hz mode. This is a test restriction, not a panel rating.
Do not enable it in a release configuration or compositor policy.

The full DRM mode clock and horizontal total give 2,329 maximum vertical
lines for that request. Each INTF multiplies this count by its actual
programmed horizontal period after split/DSC conversion. Overflow, register
readback failure and unequal periods reject activation. Both DSI hosts are
validated under the existing bonded lock order before either is changed.
A failed host readback clears AVR on both hosts. One logical encoder owns
enable/disable and triggers both interfaces after their shared CTL flush.
Disable and hardware-reset paths clear both interfaces before host cleanup.
Leaving VRR for another fixed mode uses a full modeset; the existing DFPS
shortcut is excluded while either atomic state requests VRR.

The existing encoder debugfs `status` reports software `avr_enabled`.
It does not measure panel cadence. Register snapshots, DRM timestamps and
frame presentation also remain separate from calibrated optical/TE evidence.

## Validation and device procedure

The actual-source host test is `bash tests/o82-avr-contract.sh PREPARED_KERNEL`.
It executes rational timing and overflow boundaries, INTF operations, bonded
host validation/readback rollback, and logical encoder transitions with
injected failures. The existing DFPS atomic test additionally rejects the
shortcut for old or new VRR state. RPM `%check` runs the AVR test.

Before a device trial, preserve the current boot bundle and matching modules,
record the exact panel/build/configuration and coordinate exclusive display
and reboot access with any other session. Use an isolated kernel release
and the existing guarded boot update path. Enable the parameter only in
that test boot. Keep the installed fallback and Android return route.

1. Record fixed 120 Hz scanout, both INTF/DSI register snapshots, DRM events,
   touch state and the kernel log.
2. Obtain DRM master or a valid lease using the distribution's KMS tools;
   request `VRR_ENABLED=1` only with the exact current 120 Hz mode. Test-only
   atomic requests for another mode must fail before hardware changes.
3. Deliver reproducible irregular frames near the 8.333–8.402 ms experiment
   interval. Correlate frame IDs, DRM events and calibrated optical/TE capture
   on both panel halves. Stop frame delivery to check the bounded repeat.
4. Request `VRR_ENABLED=0`, verify both hosts/INTFs leave AVR, and repeat the
   fixed-mode baseline. Check full modeset, DPMS and suspend/resume separately.

Physical cadence, receiver tolerance, flicker, input behavior, reset/recovery
and suspend acceptance remain required before advertising VRR capability.
The parameter alone is not an end-user Adaptive Sync implementation.

Sources: [Uke OEM display drivers](https://github.com/MiCode/vendor_opensource_display-drivers/tree/44275c404a677d9d9e5230fedd1af2ef02fc7b9a),
[PortareOS AVR patch](https://github.com/portare-ch/portareos/tree/67ed458421d919aba9c687c3f72d7678954b6902),
[standard DRM semantics](https://docs.kernel.org/gpu/drm-kms.html#variable-refresh-properties).
