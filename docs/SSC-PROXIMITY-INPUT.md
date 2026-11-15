# Native SSC proximity input candidate

This additive source candidate exposes the existing validated near/far bit as
`EV_SW/SW_FRONT_PROXIMITY`. It leaves the raw IIO channel, SSC messages, units,
calibration, DT topology and other sensor streams unchanged. It adds no daemon,
module, Kconfig option or runtime RPM. The existing SSC module already depends
on input for its Hall-aware combined light endpoint.

An input open acquires a shared per-SUID demand and waits for a current admitted
sample before returning an initial switch state. Closing releases only that
demand. The auxiliary bit is shared with combined-light ownership because those
consumers have disjoint sensor kinds and SUIDs. Raw direct and buffered readers
continue to own their independent demands. Namespace loss withdraws data;
normal reconciliation restores an open input consumer. Registration and removal
run outside the controller mutex because input handlers may synchronously open
or close the device. There is no timer or new SSC polling path.

Fedora SensorProxy 3.9 has an input proximity backend using this standard switch.
Its integer IIO threshold backend cannot distinguish this sensor's unscaled 0/1
values with its strict hysteresis comparisons. Inventing a distance or changing
the existing raw ABI is not an appropriate fix. The input backend's GIO channel
release behavior also needs upstream review before claiming demand/power parity.
This candidate does not replace or retire the currently installed provider.

The kernel patch is original GPL-2.0-only integration. SensorProxy 3.9 is reviewed
as a GPLv3 consumer contract; the input file specifies GPL-3.0-only and none of
its implementation is copied.
The AOSP CHRE SEE helper at `d020c8b148343e39140397e5a38e1431307fadd2`,
`platform/slpi/see/see_helper.cc` (Apache-2.0, AOSP), independently interprets the
proximity enum as a near bit. It is protocol comparison, not copied kernel code
or proof of Uke's physical sensing range. Existing exact Uke SSC metadata and
decoder admission remain authoritative for selecting the endpoint. No unrelated
board GPIO, register, firmware or calibration is transplanted.

Native acceptance requires actual callback tests under GCC/Clang, plain and
ASan/UBSan, the complete retained cumulative checks, and the actual AArch64 SSC
composite. Physical acceptance separately requires initial near/far, event
delivery, simultaneous IIO/input access, last-close demand, DSP restart,
suspend/resume, sensor selection and original Fedora D-Bus parity. Full kernel
delivery and provider retirement are not authorized by a source receipt alone.

The cumulative delivery adapter includes proximity and crash-history assets in
both native-profile and boot-recipe archives. Full builds apply both patches
after retained source preparation and before building the Image and modules.
Final checks inspect the actual new SSC module and built-in remoteproc symbols;
they do not substitute older source or objects. The original dual-light and
legacy SSC comparisons use a SHA-pinned inverse of only the additive proximity
patch. Unrelated source changes must still fail those comparisons.
Temporary inverse work is isolated from the prepared kernel Git repository;
otherwise Git can ignore patch paths outside the current nested directory.
The source test covers this real preparation context and preserves actual input.

The full-spec text test is pinned to successful full9 (11289655), verifies a
whole-text inverse and rejects invalid ordering, missing dependencies, duplicate
anchors, a stable-family input or repeated application without changing rejected
input. Compiler/sanitizer suites stay in source qualification rather than being
rerun during every full build. Full delivery also requires the exact-source
receipt and `uke-control(critical-crash-count-v1) >= 1`. These delivery checks do
not establish physical sensing, power parity or a safe provider retirement.
