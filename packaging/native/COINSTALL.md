# Retained kernel package installation

30 October 2026. Fedora Rawhide AArch64 on POCO Pad X1: native RPM test of
kernel51 alongside retained kernel49 refused a conflicting README at the
unversioned package documentation path. No kernel was installed or activated
by that failed transaction.

Release52 installs the README under its exact kernel release and declares the
selection RPM install-only, matching its payload packages. The COPR source
worker preserves every non-specification input byte from successful build
[11228360](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11228360/).
The parent SRPM SHA256 is
`93b1a04660b5bc208031900985649a10c433ef5302f98e10cc883732fd001d28`.
That source retains the release50 profile plus the reviewed release51 video
overlay; this correction changes packaging and the kernel release suffix.

All native compilation and checks run in COPR. Source preparation verifies the
parent specification and all unchanged source files. Package validation must
then confirm retained-kernel installation without file conflicts. Running49,
RAM-only video changes, newly installed modules and an activated kernel remain
separate identities. Keep automatic activation disabled during the active
tablet session; successful packaging does not establish boot or device acceptance.
