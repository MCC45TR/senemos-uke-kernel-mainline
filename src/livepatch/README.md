# Signed livepatch preparation

15 November 2026 candidate for7.3.4-2-unstable. The user requested livepatch
to investigate camera fixes without repeated full-kernel builds. ARM64 already
selects HAVE_LIVEPATCH and reliable stack tracing; the current configuration
also has dynamic ftrace with arguments and KALLSYMS_ALL. The final build adds
LIVEPATCH and one pinned public signing certificate. Historical reference
configs and every other security setting remain unchanged.

The existing generated kernel/module signer remains. MODULE_SIG_FORCE,
lockdown integrity and SELinux remain mandatory. A separate dedicated public
certificate permits later externally built patches to use a persistent signer;
its private key is excluded from Git, source RPMs, public artifacts and COPR.
This does not turn an arbitrary camera module into a valid livepatch. Future
patches require exact target ABI/source/symbols, a supported function transition,
verified signatures, normal RPM/DNF delivery and an actual load/unload test.

The metadata test checks the exact two-setting inverse and refuses an unknown
certificate, altered certificate, unsigned-module configuration, missing
lockdown/SELinux or disabled livepatch. COPR must resolve the actual ARM64
configuration, compile the livepatch composite and keyring/certificate objects,
and compare the embedded extra certificate with its pinned DER bytes. These
gates do not prove a signed patch loaded on Uke or that either camera works.

Primary implementation contracts: Linux7.3.4 `kernel/livepatch/Kconfig`,
`arch/arm64/Kconfig`, `certs/Makefile`, and the Linux
[livepatch](https://docs.kernel.org/livepatch/livepatch.html) and
[module ELF format](https://docs.kernel.org/livepatch/module-elf-format.html)
documentation. New project code isGPL-2.0-only. This module trust anchor does
not establish OEM-to-Linux Verified Boot or hardware-sealed storage keys.
