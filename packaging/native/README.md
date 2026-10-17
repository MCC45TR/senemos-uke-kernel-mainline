# Mainline display source profile

17 October 2026. The native O82 profile is part of
`senemos-uke-linux-kernel-mainline`; there is no separate native kernel package.
The root `make srpm` and `.copr/Makefile` use one specification and source
producer. `packaging/native/Makefile` remains a compatibility SCM entry pointing
to the same producer. EL2 work remains separate.

The source RPM contains signed Linux 7.2.10, the 44 ordered Uke base patches,
the ABL adaptation, native DPU/DSI patches, the exact O82-42 seven-mode overlay,
configuration, contract checks, source commit and asset hashes. Numeric Senemos
build releases have separate module paths. Install-only packages do not obsolete
or overwrite a previous kernel build.

The binary tuple contains a raw Image, matching modules, independent DTB and
native overlay. It currently has **no embedded initramfs or Android boot
container** and performs no boot writes. A successful COPR build is a source
and compile result. It does not qualify this package as an install-tested boot
update. Keep the existing validated boot bundle and rollback until the public
initramfs producer has passed its own package and tablet tests. The historical
standalone host recipe under `configs/host/` is not this native source producer.

Commit `4eb69e5`, published as `feature/dnf-stock-abl-updates-20261015`, contains
a dracut and guarded boot-container producer. Its older framebuffer configuration and early-module
inventory require integration with this profile before enabling automatic
mainline boot updates. Private initramfs files, firmware, credentials and
per-device calibration are not source inputs here.

Upstream Linux's MSM register generator
`drivers/gpu/drm/msm/registers/gen_header.py` has SHA-256
`81763fc03ea0ebf254ab7427af2113dc0c7c0d80dceab61232b6e371463d1f90`.
It converts upstream XML into register headers and is an unavoidable host-only
Python build dependency. No project Python or Python payload is supplied to the
tablet; package installation checks reject Python files and runtimes.
