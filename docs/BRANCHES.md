# Development branches

31 October 2026. `main` is the continuation branch, `kvm` retains the isolated
KVM/EL2 package producer, and `test` retains its test integration history.
These are the three retained development branches. Source integration does not
establish package, VM or tablet acceptance.

The former `KVM` and `TEST` tips are retained exactly by the lowercase branch
renames. The microphone106 source tip is reachable from main through merged
PR #46. A merged topic branch can therefore be removed without losing commits.

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
admission or publish the retained release106 identity with changed binaries.
Choose and recheck a fresh release immediately before a separately authorized
build; no release number is reserved by source consolidation.

Historical `packaging/native/copr-*.sh` overlay workers describe their original
pinned-parent trials, not a supported producer for the combined source. Use
the original archived commit to reproduce those trials; their overlay lists
must be revalidated against the complete source lock before reuse. The
canonical source entry and its channel refusal remain unchanged.

The refreshed PR #46 tip declares automatic inactive-slot delivery in package
metadata. The boot package retains the stronger updater 1.9.0 requirement and
all final-transaction and boot-reset capability requirements. This source change
does not install packages, activate a slot or enable a main-push build workflow.
Existing COPR webhook configuration is separate from GitHub Actions triggers;
it was not changed or independently qualified by this consolidation.
