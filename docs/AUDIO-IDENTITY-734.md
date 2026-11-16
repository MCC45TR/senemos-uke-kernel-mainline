# Audio identity before a full build

16 November 2026. Full candidate 11332108 built its Image and modules, then
failed the retained MST check because source composition stored the dotted
firmware alias as the ALSA driver identifier. No runtime RPM was released.
The canonical tuple distinguishes `uke7_3_4-2u` from `uke7.3.4-2u`.

The source worker now records `audio_driver` directly. Full assembly accepts
only that canonical value or the exact erroneous firmware alias from the
qualified source, and normalizes that one metadata field. Other inherited
composition fields, runtime sources and the signed native13 source proof
remain checked. This correction does not require recompiling unchanged
production sources in another source-check job.

The full build checks metadata before Image compilation and compiles one
actual ARM64 audio object in a disposable, independently configured output.
Its dotted alias must match the tuple. The original final MST check remains;
the new check also validates the actual linked audio module. Neither check
reuses a preflight object in the production build.

PC data checks reject the old metadata and invalid driver, ABI and revision,
and the complete full28 recipe inverse passes. Native preflight, full package
signatures, DNF delivery and physical audio remain separate pending results.
