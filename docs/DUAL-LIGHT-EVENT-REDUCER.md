# Dual ambient-light event reduction

8 November 2026. This is a source-only preparation milestone. It does not add
an IIO device, acquire SSC streams, subscribe to Hall input or control a display.
The full-build entry point refuses this incomplete integration. The accepted
7.3.3-5 kernel and existing sensor providers remain unchanged.

The requested behavior is rear-only illumination while the cover is closed,
including use by an external monitor. With the cover open, preserve the existing
front/rear selection. Desktop automatic-brightness preferences, the lux-to-nit
curve and external-monitor DDC transactions remain in their standard userspace
owners. The kernel must not impersonate those preferences or alter lux units.

The reducer accepts already admitted, calibrated integer micro-lux events.
It requires both channels in open or unknown-cover mode. A verified closed
cover requires only the rear channel and ignores front events. Reopening
invalidates the previous front measurement until a fresh indication arrives.
Acquisition epochs advance across every stop/restart, even within one DSP
namespace. Old epochs, duplicate or regressing per-channel timestamps and
negative values cannot update output. Stop clears readings. Equal reduced
values do not generate another output. There is no hardware request, periodic
timer, sleep, worker or polling loop in this reducer. Its owner must serialize
access and retain all existing SSC metadata, ACK, sample-status and lifecycle
gates. The raw front/rear channels remain part of the integration contract.

The existing project SensorProxy combines two SSC channels using their maximum.
That previously accepted user experience is the compatibility baseline; this
review does not independently prove the full HyperOS algorithm. No GPL-3.0
SensorProxy implementation is copied into the GPL-2.0 kernel helper. Source
comparison uses the unchanged original SensorProxy 3.9 archive, SHA256
19a4ae99b1b8af603fc789841025f9747bf445418d69ec7389e75adb6c8186bf,
and the actual installed 3.9-24 source package from COPR 11228192. Exact Uke
STK3BCx/SIP1328 metadata and units remain those of the accepted native SSC
implementation. Same-SoC and other-panel material does not authorize new board
values. No matching upstream dual-physical-sensor reducer was established by
the bounded current IIO queue review.

Original SensorProxy 3.9 reads a direct IIO ALS every 800 ms. Its buffered ALS
reader also uses a 700 ms timer and specifically decodes `in_intensity_both`.
It does not provide an event-driven, standard `IIO_LIGHT` integration for this
pair merely because a kernel node exists. Keep genuine `IIO_LIGHT` units and
raw channels: do not rename illuminance as intensity, truncate 64-bit micro-lux,
add a resident adapter, or retire the working provider to conceal that gap.
The native buffered endpoint, subscription ownership, event-driven Hall link,
initial switch validity, suspend/restart recovery and original-daemon upstream
support remain required work. Hardware power and physical parity need separate
measurement. DDC capability and monitor preference also need real acceptance.

The COPR-only contract compiles the actual header under GCC and Clang, with and
without ASan/UBSan, rejects five behavioral mutants per compiler and compiles a
small consumer with real AArch64 kernel headers. That consumer is a test object,
not the shipping SSC driver. The cumulative driver, DT and native config stay
byte-exact and all previous sound, Hall and memory gates must pass again. These
tests cannot establish sensor, cover, display, power or suspend functionality.
