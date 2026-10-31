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
