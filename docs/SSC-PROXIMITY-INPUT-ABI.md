# Select the native proximity input interface

The original Fedora SensorProxy 3.9 discovers IIO before input. Its integer
proximity polling backend cannot represent Uke's retained raw `0/1` channel:
it requires a nonzero integer near threshold and compares with hysteresis.
The native `SW_FRONT_PROXIMITY` input interface already provides the appropriate
initial state and events. A bounded original-package trial confirmed that it
is usable when the unsuitable raw polling device is excluded from discovery.
The trial does not establish physical near/far, power or suspend parity.

The raw IIO device's read-only `ssc_proximity_input_abi` capability returns `1` for
the declared proximity SUID supported by this driver, otherwise `0`. It is
created atomically before the IIO device's add event, allowing a small rule in the
existing Control package to select the standard input backend without a boot
race or a polling helper. Older kernels lack the attribute and retain their
existing classification. Raw IIO values and firmware stream/input lifecycle
are unchanged and remain accessible to applications. This capability is a
driver contract; it does not assert successful input registration, current
sample availability, calibrated distance or physical acceptance.

The new attribute performs no I/O, schedules no work, starts no stream and
reads no private calibration. The exact full17 source inverse, actual callback
tests and a fresh ARM64 composite object qualify source behavior separately
from full-kernel delivery and on-device acceptance. It adds no runtime RPM,
service or distribution-package fork. The control-side classification rule
must remain unshipped until its own build/package/rollback gates pass.
