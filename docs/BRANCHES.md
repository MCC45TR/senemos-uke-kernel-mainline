# Development branches

29 October 2026. `main` holds the normal integrated source, `KVM` holds the
isolated KVM/EL2 candidate, and `UNSTABLE` reserves reviewed Linux 7.4-rcN ports.
Singleboot is built as a matched package profile, not a separate branch.
Historical work is retained under `archive/2026-10-29/` tags. Experimental
firmware-exit and older kernel research are archived, not enabled by this
consolidation. KVM retains the explicit EL2 admission and separate module ABI.
External COPR SCM source branches must be updated to the canonical names.
