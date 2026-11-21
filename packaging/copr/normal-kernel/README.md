# Normal kernel in the Unstable COPR

The `copr-normal-unstable` branch builds the normal
`senemos-uke-linux-kernel-mainline` family for Fedora Rawhide AArch64.
A push to this branch triggers the Unstable COPR source worker.
Stable and Testing are published manually.

The worker verifies the signed cumulative parent SRPM and applies the
reviewed source delta. It reads the Linux version from the kernel
archive's Makefile, advances the published RPM revision, and builds
an SRPM with the same version and revision in the kernel ABI. The
current plan moves from RPM 7.3.5-32 to the kernel ABI 7.3.5-33.

Advance the reviewed plan from the next signed parent when preparing a
new cumulative release. The worker rejects a release that already has
a successful published build. Its boot bundle and signed RPMs still
require device validation before the release can be accepted.
