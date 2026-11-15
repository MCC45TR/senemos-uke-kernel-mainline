# SSC acquisition time and gravity frame

13 November 2026. Native108 and cumulative full25 correct streaming buffer
joins. They retain host-arrival IIO timestamps; neither establishes acquisition
time or a gravity mount transform. The installed24 endpoints currently select
the standard `realtime` IIO clock, with accel/gravity buffers disabled during
the passive inspection. No clock, buffer, rate or sensor request was changed.

## Clock contracts

The pinned Qualcomm `sns_client.proto` leaves timestamps sensor-defined and
typically expressed in ticks. Its standard sensor schema requires on-change
events to preserve the last state-transition timestamp. A cached sample must
therefore retain its accepted acquisition timestamp, including when another
consumer joins. A host receive time alone cannot establish its age.

Qualcomm's `qshTimeUtil.h` reads CNTVCT and CNTFRQ, converts QTimer ticks, then
maps their epoch to the host clock. Pinned32955196 and current6363cb4a have
identical implementation bytes after the SPDX line; the license changed from
BSD-3-Clause-Clear to BSD-3-Clause. The non-Android implementation uses
CLOCK_REALTIME, whereas its Android branch uses elapsed realtime. Its floating
point, minute-based updates and public-offset workaround are comparison
evidence, not code to copy into this driver.

Exact Uke OEM5712080a and same-SoC OnePlusfc892483 ARM timer implementations
are byte-identical. The accepted Linux7.3.3 d50d994b and current upstream
7e1392a4 timer source/header are also identical. The current kernel exports
`arch_timer_read_counter` to GPL modules, but not `arch_timer_get_rate`;
ARM64 supplies an inline `arch_timer_get_cntfrq`. A module must respect those
actual interfaces and architecture errata, rather than add an unresolved
frequency-symbol dependency or a hardcoded19.2MHz assumption.

The next kernel layer needs a qualified mapping from the fitted SSC timestamp
domain to the selected IIO clock, with bounded capture uncertainty, overflow
and future-time rejection, suspend/reset generation invalidation, early-ACK
retention and acquisition time preserved for cached on-change data. Counter
agreement on this firmware remains unmeasured. No clock capability is exposed
by full25; a kernel-version check is not semantic admission. Kernel callbacks
must remain event-driven, without an idle timer or hardware poller.

## Frame contracts

Qualcomm `sns_accel.proto` defines device coordinates; `sns_gravity.proto`
defines gravity XYZ followed by linear acceleration XYZ in matching units.
Their per-axis subtraction suggests a common fusion frame, but this is an
inference, not proof of the fitted Uke endpoint or its display transform.
Android's application sensor contract likewise describes accel/gravity in the
same device frame; a HAL contract alone does not prove the raw SSC interface.

The existing accel landscape matrix is board/display metadata, distinct from
OEM sensor-bus orientation. Gravity currently has no standard IIO matrix.
RIGID_BODY19 is an integer array of dependent bodies, not axes. Attribute20 is
reserved in the pinned public schema; libssc0.4.4's private mount-matrix20
interpretation is not a generic protocol contract and its GPL3 code is not
copied. Unknown/ambiguous frame remains unknown; no identity fallback or matrix
borrowed from another endpoint is admitted.

The current SMGR IIO patch series describes a different QMI service/protocol;
no matching upstream Uke SSC400 frame/time implementation was established by
this bounded review. Source identities, licenses and hashes are in the
[review manifest](../manifests/ssc-frame-time-review-20261113.json).
The remaining native IIO and original Fedora SensorProxy parity work stays
active. Existing Control may prepare its leased Motion1 interface, but its
production gate stays closed until both frame and acquisition time qualify.
