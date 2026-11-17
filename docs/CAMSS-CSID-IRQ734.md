# SM7675 CSID completion interrupts

17 November 2026. Source candidate; COPR qualification is pending. Accepted
full8/B remains installed. No receiver graph, sensor or frame is activated.

The selected Uke CSID860/lite860 descriptions use the GPL CSID880/lite880
tables. Both exact MiCode camera source at
`699fa15a98abd40fbb94f3a6fc00f91723d29d35` and same-SoC OnePlus source at
`1138e00fee63582a0cc6a53af3286621786827b7` agree on the relevant interrupt
fields. Their complete files differ in unrelated vendor error classification;
the fixture compares the selected fields independently.

Linux 7.3.4 gen3 reset writes one buffer mask bit on each loop iteration,
replacing the earlier channels. It enables only reset completion at the top
level and does not enable the per-RDI register-update completion mask. The
SM7675 candidate accumulates the selected buffer bits, enables their documented
top-level route and enables RUP completion for each selected RDI. Delivery
remains masked until owned status is cleared and the masks are prepared.

The exact top-level buffer route is bit 13. A reviewed upstream SA8775P pixel
path proposal uses bit 14 for its different layout; that value is not copied.
The source manifest pins all original inputs and their licenses. Original
Linux/Qualcomm attribution remains, with Qualcomm Innovation Center attribution
for the SM7675 table-derived addition.

The current native full VFE exposes three RDI lines, while lite exposes four.
The new reset path refuses unsupported masks before MMIO. This qualifies only
the existing RAW receive backend; additional OEM processing paths remain open.
Every other platform follows the complete original reset sequence.

The COPR test imports the actual reset, ISR and update callbacks, and derives
the oracle from independent CSID fields and VFE completion-group tables. It
requires GCC/Clang plain and sanitizer modes, original failure controls,
48 reset/timeout cases, 1152 independent/combined frame and RUP events,
488 invalid masks, 96 unchanged legacy traces, five semantic mutants and an
actual ARM64 object. Modeled MMIO and interrupts do not establish hardware
operation or a completed frame.

Stream-on register-update ordering is a separate remaining contract. The
[upstream proposal](https://lore.kernel.org/linux-media/20261011-kaanapali-camss-v21-4-04fd28d815c6@oss.qualcomm.com/)
discusses issuing the initial update after receiver configuration. This reset
change does not claim to implement or qualify that ordering. The HF interconnect
route, complete aggregate resources, fitted sensor identity/address/power/lanes,
private read-only calibration and rear focus also remain open.
