# Battery status events and cycle metadata

11 November 2026. Source candidate over cumulative full19. Native compilation,
package delivery and Uke physical acceptance are separate gates.

The exact Uke OEM kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
`drivers/power/supply/qti_battery_charger.c`, routes notification payload0x50
through battery `power_supply_changed()`. The adjacent shared-IP Peridot
revision `2ed9eadbecae21ef51134e556951e7305ba65f88` does likewise. Both retain
GPL-2.0-only Linux Foundation/Linaro/Qualcomm attribution. The existing Uke
native patch0122 supplies this missing standard event. It does not treat a
raw opcode0x50 reply as a notification or add an XM property request, pen
worker, periodic loop, desktop policy or charger operation.

Existing patch0124 independently accepts a successful zero cycle-count report.
Zero is representable counter metadata. Negative/sentinel and oversized
values stay unavailable; voltage/full-capacity positive-only validation is
retained. OEM and upstream return the reported count; this does not establish
the fitted gauge's age semantics or enable a charging-age policy.

Use the actual cumulative full19 source, not a later working manifest. Apply
only these two patches and prove their complete inverse. Exercise the actual
notification and validator bodies with GCC/Clang and sanitizers, including
wrong length, non-Uke variants, unknown events, ordinary battery/USB/wireless
events, zero and overflow. The old event discard and zero-counter rejection
must fail the corresponding checks. Build the real ARM64 battery object.

These changes complete event delivery and metadata semantics only. They do
not establish effective70/80 cutoff, persistence, full100 termination,
JEITA, aging, pack protection or45W. Firmware charging ownership remains
unchanged. Qualify the electrical behavior separately, retaining fixed-cap
quarantine, the current config/audio/DT tuple, gain223 and accepted rollback.
