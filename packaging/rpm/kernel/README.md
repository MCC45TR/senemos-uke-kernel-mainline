# Fedora Rawhide AArch64 kernel RPM

`release-plan.json` identifies the signed parent. `inputs/SHA256SUMS` pins
the release inputs. The worker applies `inputs/parent.patch`, compares the
result with the checked-in spec and preserves the published archive names
and RPM identities.

The 7.3.5-46 recipe uses 7.3.5-45 from COPR build 11372229 and supplies three
additional source archives. See the [build guide](../../../docs/development/building.md)
for source verification and COPR entry points.
