# Native display source-build gate

17 October 2026. This experimental package builds the complete native54 kernel
source profile from the signed Linux 7.2.9 archive, all 44 ordered Uke base
patches, the ABL adaptation, native display patches and the explicit O82-42
seven-mode overlay. The source RPM retains all preparation code, tests,
configuration, asset hashes and its source commit. It includes the shared-reset
readiness boundary and live refresh timing candidate, with all seven-mode host,
panel and atomic-commit contract checks. Visible transitions and continuous touch
input require separate physical testing.

The package is named `senemos-uke-linux-kernel-mainline-native` and uses a
separate `7.2.9-senemos.1.4054.copr2` module directory. It neither replaces the
normal kernel packages nor writes a boot partition. It contains a raw Image,
matching modules, independent compile-stage DTB and the compiled native overlay.

**Compile-only development gate.** It has no embedded initramfs, Android boot
container, firmware, credentials or per-device data. It cannot reproduce the
currently tested boot image and must not be presented as an install-tested
kernel update. A public, reproducible initramfs and boot-container producer is
required before it can supply the guarded boot-update bundle. COPR build
success does not establish tablet boot, refresh switching or lifecycle support.

The upstream Linux 7.2.9 host tool
`drivers/gpu/drm/msm/registers/gen_header.py` generates MSM register headers
from the kernel's XML descriptions. Its pinned SHA-256 is
`81763fc03ea0ebf254ab7427af2113dc0c7c0d80dceab61232b6e371463d1f90`.
The upstream build requires this generator; replacing its parser would add a
second register-definition implementation. Python is a host-only build
dependency, with no project Python code or Python payload in the binary RPMs.
The package install check rejects Python scripts or runtime files.

Use a COPR side repository named `native-display`, limited to
`fedora-rawhide-aarch64`, with SCM method `make_srpm` and subdirectory
`packaging/native`. The normal `.copr/Makefile` and package recipe remain
unchanged. From this directory, `make srpm` creates a source RPM; the source
archive verification uses the existing pinned upstream manifest and signer.
