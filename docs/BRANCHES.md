# Development branches

31 October 2026. `main` holds integrated source, `KVM` retains the isolated
KVM/EL2 package producer, and `TEST` retains its test integration history.
These are the three retained development branches. Source integration does not
establish package, VM or tablet acceptance.

Historical branch heads remain in `archive/branch-prune-20261031/` tags.
The completed one-time pruning workflow is not an active maintenance mechanism.
Future cleanup must first verify that each exact tip is reachable from `main`;
never delete an unmerged tip or rewrite these three branches by force.

Main's ordinary package identity, native touch integration and transactional
updater remain unchanged by the KVM source consolidation. The optional KVM
entry is not enabled by main's producer; see [KVM source boundaries](../KVM.md).

## Consolidation validation

31 October 2026, Debian 13 x86_64 host fixtures: the integrated source retains
PR #46 microphone capture, PR #47 opt-in boot watchdog, PR #48 optional gaming,
KVM source helpers and TEST input inventory. RPM metadata, microphone topology
and desktop policy, source hashes and host contract checks passed. Sanitizer
leak detection was disabled because the sandbox does not support its ptrace
requirements. No kernel compilation, package installation, VM or tablet test
was performed.

The ordinary `make validate`/`make srpm` channel admission still refuses the
retained Linux 7.3.1 version: the inherited unstable-channel policy requires a
separately reviewed Linux 7.4-rcN source queue. The source-contract body was
checked separately without authorizing a build. Do not treat this as release
admission or publish the retained release105 identity with changed binaries.
Choose and recheck a fresh release immediately before a separately authorized
build; no release number is reserved by source consolidation.

Historical `packaging/native/copr-*.sh` overlay workers describe their original
pinned-parent trials, not a supported producer for the combined source. Use
the original archived commit to reproduce those trials; their overlay lists
must be revalidated against the complete source lock before reuse. The
canonical source entry and its channel refusal remain unchanged.
