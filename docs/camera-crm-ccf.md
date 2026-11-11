# CRM clock callbacks and controller power management

5 November 2026, Linux 7.3.1, Xiaomi Uke / SM7675.

The eight AP SWDRV0 RCG clients use the qualified CRM vote/LUT implementation
through the permanent provider's actual prepare, PRE, set-rate, POST and
unprepare wrappers. A prepared change sends the complete acknowledged vote in
the checked PRE callback after voltage increases. Linux 7.3.1's set-rate callback
commits the acknowledged software request without further I/O. ABORT restores
the previous completed vote before voltage cleanup. A timeout or ambiguous
completion preserves voltage and permanent resources and prohibits retry.
An unprepared change updates only the software request. Recalculation reports
that request rather than another firmware client's aggregated hardware rate.

The adapter caches the admitted ROM table, resolves its actual parent map,
uses the parent's present rate only as a topology hint, and removes parent-rate
propagation. Native RCG enable/disable/configuration callbacks are excluded.
The BW request retains the OEM whole-MHz IB/AB0 protocol and rejects a conversion
that would select a different ROM performance level. Unsupported rates refuse
before voltage changes.

Controller runtime suspend invokes the owned transport's idle/readback/drain
path before disabling its interface or removing rail votes. Busy votes keep the
controller active. Resume restores rails and interface before identity checks
and IRQ rearm; a rearm error retains every resource rather than rolling power
back under a potentially live permanent IRQ. Hooks are initially absent and
may be installed only after transport ownership succeeds.

Qualification requires the existing core/IRQ/LUT/post-drain controls, actual
provider and voltage callback fault tests in four compiler/sanitizer modes,
five destructive mutants, and real AArch64 objects for the complete built-in
provider and adapter entry points with `-Werror`. Compilation stays in COPR;
the text receipt is not installed on the tablet.

This source step does **not** activate firmware CRM. The original active-CRM
guard remains unchanged. Permanent cfg/CRMC mapping and exact IRQ DT migration,
all 38 managed PLL/divider/RCG/branch objects, parent-rate snapshots, inherited
AP votes and their sync-state withdrawal must be integrated before attachment
and provider publication. The full cumulative kernel and physical controller
admission remain separate. There are no camera frames, fitted EEPROM
calibration-consumption results, rear AF/parking results or camera acceptance.

Protocol and layout attribution remains in the core, LUT and transport headers.
Pinned OEM, same-SoC and upstream/CCF sources are recorded in
`manifests/camera-crm-source-review-20261105.json`.
