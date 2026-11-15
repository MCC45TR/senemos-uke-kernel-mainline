# Speaker routing for display transforms

The Uke machine driver adds one `Speaker Display Rotation` ALSA enum with
0, 90, 180 and 270 degree values. It validates the complete existing codec
control ABI, reads all four old values before writing, reads back the result,
and restores every previous value after an error. If restoration cannot be
verified it enters the existing latched FS19xx fault path. It does not change
gain, calibration, PCM formats, DSP protection or microphone/DP routing.

The existing DT speaker link identifies the four FS19xx endpoints and their
TopLeft, TopRight, BottomLeft and BottomRight prefixes. The codec retains the
OEM position masks from the device's private preset and its existing channel
register implementation. No private preset or measured coordinates are added
to generic DT. Per-amplifier controls remain for older userspace. The aggregate
getter reports inconsistent legacy writes rather than inventing a common value.

The active local session still supplies the committed internal display
transform. A KMS plane rotation is not necessarily the desktop transform: a
compositor can render an already rotated framebuffer, and an external display
must not become the tablet's orientation reference. Raw accelerometer events
would also ignore the user's rotation lock. The existing minimal session
integration can prefer this single native control and retain its old-kernel
fallback; no compositor fork, sensor polling or new daemon is required.

The source check runs the actual routing transaction under GCC/Clang and
sanitizers, then compiles the real ARM64 machine driver. Full delivery inspects
the actual linked card and all module signatures. Four physical speaker
directions, manual rotation, rotation lock, DPMS, closed cover with active DP,
fault behavior and suspend/resume remain separate device acceptance tests.

The reduced full-build recipe keeps the complete preparation inputs, package
installation section and file lists, normal Image/module compilation, critical
linked checks and cryptographic verification of every shipped module. Source
regressions and inspection-only recompiles are qualified through the same
commit's source receipt instead of repeating them in each full job. No package
or hardware feature is removed to reduce build time. The 1200-second target is
not yet measured or guaranteed; the previous four-CPU kernel compile alone took
1136 seconds. Queue and source-worker time must be reported separately.
