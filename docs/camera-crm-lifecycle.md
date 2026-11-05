# Cliffs camera CRM IRQ and power lifecycle

The AP vote/IRQ/LUT foundation is qualified by COPR11264111 on the full12204
source and configuration. The following source layer implements IRQ quiesce,
resume and clean release. It is still disconnected from the running provider;
managed CCF and runtime-PM wiring remain necessary before physical admission.

An idle transition requires all owned Linux and inherited AP SWDRV0 ACTIVE,
SLEEP and WAKE votes to be zero. It never withdraws an inherited vote or changes
firmware/HW voters. Nonzero data returns busy with no register write. Unexpected
status or format bits preserve a fault and resources. Known BCM packet flags
may remain when both AB and IB fields are zero.

Only after the complete idle scan does the transport disable its eight IRQ
enable registers, verify each readback, and drain the registered handler before
the owner may remove power. Suspended IRQ callbacks perform no MMIO. Resume
requires powered access, unchanged version/capabilities, enabled firmware CRM,
zero owned votes/status and disabled owned IRQs before rearming them. Partial
disable or rearm failure quarantines the controller and retains ownership.
The CRM enable and HW/channel registers are never written.

Clean unpublished release first quiesces and drains, then retires the IRQ before
the caller may unmap its resources. Faulted state cannot release or retry.
Admission is repeated under the transaction lock, preventing a release between
the initial check and lock acquisition from causing a second free or MMIO on a
retired mapping. Runtime suspend/resume keeps the registered IRQ; release is
for clean owner teardown, not an automatic fault-recovery shortcut.

The extended actual-body fixture covers inherited votes in every owned state,
powered-off IRQ/vote refusal, sixteen partial transition failures, identity and
status drift, and three release/lock interleavings. The real AArch64 object
must generate the idle/resume paths and reference synchronize_irq/free_irq.
No source test constitutes physical PM, camera capture, calibration or focus
acceptance. The running firmware CRM guard and all sensor/capture gates remain.
