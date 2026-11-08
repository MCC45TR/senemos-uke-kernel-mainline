# Native dual-light endpoint and lid input

8 November 2026. Source preparation after shared-owner admission
COPR11286027/source28. This source-only entry refuses full kernel builds. The
implementation is not installed on a tablet. Native, binding, provider and
physical acceptance are separate requirements; a registered endpoint is not
proof of comfortable or OEM-equivalent automatic brightness.

The existing SSC driver gains a standard IIO_LIGHT endpoint with signed64-bit
integer micro-lux, scale0.000001, a soft timestamp and kfifo buffering. The raw
front/rear channels and their existing units remain. Direct and buffered pair
demand share the already qualified stream-owner layer; only the last owner
stops a SUID request. Open or unknown cover requires both admitted sensors and
uses their maximum, retaining the existing selection baseline. A verified closed
cover requires only the rear sensor. Opening invalidates the old front sequence;
a separately held, unchanged front on-change stream may delay its first new
indication. Do not restart another consumer or invent a post-open measurement.

The optional board `lid-switch` phandle selects the exact existing SW_LID input
parent. The handler is a passive observer; it does not start input hardware or
grab events. It snapshots the switch and resynchronizes after input grabs.
A false initial input bit is unknown until reported, rather than a fabricated
open event. Input callbacks only change state and queue the existing serialized
worker; all blocking QMI requests stay under its existing control mutex. The
buffer receives admitted events directly, without a new timer or polling task.

Stream or namespace changes invalidate the pair and its cached result. Local
acquisition epochs do not create an on-wire epoch for same-SUID delayed reports;
the existing client, metadata, ACK, status and timestamp admission still apply.
Suspend closes the QMI client and retains demand for metadata-qualified recovery.
Probe unwind and removal invalidate first, withdraw input/QMI callbacks, drain
work, unregister readers outside the control mutex, then destroy the queue.

The early DT helper links already admitted Uke front/rear descriptions to its
existing lid input. It validates exact board, datatype and switch code before
writing, preserves existing handles and is idempotent. No GPIO/IRQ value,
firmware identity, factory calibration or brightness curve is embedded. The
binding adds an optional phandle and the driver declares its input dependency.
The source-check config already has INPUT=y and must remain byte-exact.

Tests compile actual endpoint/owner/input/PM/shutdown callbacks with controlled
SSC, IIO and input providers under GCC/Clang, plain and ASan/UBSan. They cover
owner permutations, cover transitions, unchanged values, fresh-front admission,
direct timeout/reset errors, register/open failures, passive input snapshots,
suspend/recovery, partial probe registration and removal. Six intentionally bad
implementations per compiler must compile and fail behavioral assertions. Every
original QMI assertion is rerun against the postimage with extractor-only host
declarations. Libfdt tests cover valid/existing handles, idempotence and ten
invalid board/type/lid references. Actual ARM64 SSC composite and early DT
objects must compile after every retained legacy check, preserving config,
kernel release and UTS header identities. Binding validation is still pending.

Attribution and compatibility review retain
`manifests/dual-light-events-20261108.json` and the shared-owner source28 evidence.
Additional Linux7.3.3 input APIs are pinned to gregkh/linux commit
`d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`, `drivers/input/input.c` blob
`01c91fec9b7eba92835855b4531ddfafe78990c4` and `include/linux/input.h` blob
`3381608127f72d30040915e19873fc91d7315687`, retaining GPL-2.0/original notices.
Managed input allocation sets its device parent; passive observer and start
semantics are source evidence, not physical closed-cover boot acceptance.
No SensorProxy GPL-3.0 code or donor board values are copied into this GPL-2.0
implementation. No matching upstream Uke multi-sensor/lid driver was established
by the prior bounded donor/queue review; this does not claim its global absence.

Original SensorProxy3.9 still lacks the required event-driven64-bit IIO_LIGHT
path. Keep the working provider until upstream/distribution support, physical
parity, DNF upgrade and rollback are qualified. Desktop lux-to-nit preferences,
DDC transactions and external-output policy remain in standard userspace. No
new daemon, RPM, KDE/GNOME fork, lux renaming or duplicated backlight LUT is added.
The current external DDC/hub investigation remains deferred at the user request.

Source29/COPR11286049 fails425s after421 GCC normal callback assertions and
six compiled behavioral mutant refusals. The first C++ libfdt fixture rejects
three implicit conversions from `const void *`. Add explicit pointer casts in
the shared C/C++ helper without permissive flags or changed admission logic.
Review also removes a redundant timestamp initializer cast: the pinned IIO
header already supplies a typed compound literal (blob
`711c00f67371356c913ef0dbf2325e3f4d35266d`). No four-mode, DT or ARM64 endpoint
qualification follows from source29's partial result.
