# Cliffs camera CRM post-drain correction

Independent review source6fca0233537195336534b48fdd14c9371c1e4fa5,
COPR11264495, reproduced a gap in sourceaacc2b9 after its bounded lifecycle
tests passed. An owned hardware status can appear while synchronize_irq runs.
The deliberately quiesced callback performs no MMIO, so the original path can
then return clean idle or free its IRQ without observing the new status.
This is a source-model result, not an observed Uke hardware failure.

The adopted patch revalidates powered access, owned votes/status and IRQ enable
state after synchronization when this call newly quiesced the transport. A
failure preserves the fault, IRQ, mapping and power references. It neither
acknowledges the stale status nor retries. A transport already quiesced before
power-off keeps its no-MMIO clean-release path.

The review patch and fixture are retained with their exact source attribution.
The coordinator contract reconstructs the original b18add1f header by reversing
the patch from the adopted aed38b95 header, verifies both hashes, and requires
the original result assertion to fail. All sixteen PERF/BW quiesce/release
events must retain resources in GCC/Clang ordinary and ASan/UBSan modes. The
complete prior contracts and real AArch64 object remain required in COPR.

Qualification11264217 covers its recorded tests and is insufficient for provider
activation until this additional gap is corrected and validated. Managed CCF,
runtime-PM and DT integration remain incomplete. The running124 guard still
refuses active CRM; no camera, EEPROM, focus or boot action accompanies this fix.
