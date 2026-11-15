# Demand-driven native battery protection reads

11 November 2026. Source qualification over actual cumulative full21. This
change is not installed, and does not qualify charger cutoff or protection.

The existing read-only `uke_charge_protection_state` snapshot uses a valid
five-second cache without another firmware request. An expired, missing or
epoch-mismatched snapshot now uses the existing two fixed USB moisture GETs
under the driver request mutex. Firmware errors are returned as errors rather
than a successful empty record. The spinlock is released during synchronous
transport and held again while formatting one coherent snapshot. A concurrent
epoch change remains visible through the existing valid flag.

No timer, worker, retry, writer lease, firmware SET or notification capability
is added. Wet latches and fault state remain intact on failed reads. Standard
threshold observations and all full21 configuration, DT and audio features
remain unchanged. Current moisture handling is partial hardware protection;
it is not a substitute for pack/charger/thermal acceptance.

The exact Uke OEM `qti_battery_charger.c` at commit
`5712080a4b0c0b1a879e6d145c601c649ddaddfd` reads moisture state in its custom
power-supply event construction near lines9884. This supports hardware-side
ownership, but does not prove that every fault generates a notification. The
native implementation reuses its already bounded GET/cache protocol rather
than importing a second charging owner or board limits. Source remains
GPL-2.0-only; unchanged OEM references are evidence, not executed scripts.

This is a prerequisite for an event-driven consumer in the existing Control
package. The installed two-second guard remains until notification coverage,
fault action, lifecycle and electrical parity are established. Do not retire
the guard on the strength of this source test or claim all battery processes
are now event-driven.

COPR tests extract the actual read/cache/show bodies. They exercise freshness
boundaries, clock rollback, source/firmware epochs, quiescent transport, partial
errors, stale results, invalid booleans, wet latch and a formatting race in
GCC/Clang and sanitizer modes. Mutations that skip refresh or hide an error
must fail. A complete header inverse and real AArch64 battery object accompany
the text-only receipt. No native compilation runs on the tablet.
