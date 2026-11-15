# Early HWKM qualification candidate

15 November 2026. The running Uke kernel 7.3.3-26 reports ICE 4.0.2 and HWKM v2,
but its controller profile admits raw keys only. Signed diagnostic 1.0-12 from
COPR 11329763 was installed through GPG-checked DNF: real UFS selection and
4-KiB AES-XTS inspection pass; disposable-key exercise returns 77 before any key
ioctl because wrapped keys are absent. That refusal is not hardware key proof.

This candidate embeds `options qcom_ice use_wrapped_keys=1` in the forced
initramfs before the first UFS/ICE probe. It preserves the existing modular ICE
driver, original kmod dependency path, forced command line and firmware. A live
parameter change, controller reset or later vendor ramdisk cannot substitute
for this first-probe configuration. No DT resource change is needed for this
test: the fitted controller already detects ICE and HWKM. The device's full
DTBO/vendor_boot and singleboot-image work remains separate and open.

The producer starts from the exact qualified full26 SRPM, verifies its digest
and recipe, and retains every source input except the declared profile, boot
recipe and their lock. Tuple/audio identity and source provenance advance
together; raw configs and all unrelated composition entries remain equal.
Qualified passive-camera source from native112 is included without enabling
firmware CRM. Its signed receipt, source manifest and OEM oracle are pinned.

All full26 recipe statements have an exact whole-file inverse. After applying
the four passive-camera source units, the original eighteen-unit source guards
use a verified source-only full26 view. No ELF, module, Image or build output is
copied to that view or replaced. Separate final-source, actual-object and final
embedded-cpio checks protect the new cumulative output. Existing hardening,
signed-module, audio, storage, sensor, staging and recovery checks remain.

Native source qualification compiles the candidate's real ICE, SCM, UFS,
block-crypto, dm-inlinecrypt and CAMCC objects plus the all38 camera adapter.
Generation/preparation providers and UFS imports must be present. The first
source stage verifies the original kmod parse, early module list and forced
initramfs prerequisites. The source-check package contains evidence only.
The full producer refuses to run without the matching signed native113 result
and the original release allocator selecting 27. No full Image or hardware
acceptance is claimed before those stages actually pass.

After signed cumulative delivery and reboot, rerun the existing explicit
disposable-key diagnostic. Then qualify persistent long-term blob reuse across
reboot, altered-blob rejection and actual hardware encrypted I/O on owned
inactive storage. Trusted boot identity, password recovery, offline conversion,
encrypted swap and authenticated hibernation remain mandatory. Mode
advertisement or a successful kernel build proves none of those properties.

Sources retain their original notices. Linux v7.3.3
[`ice.c`](https://github.com/gregkh/linux/blob/v7.3.3/drivers/soc/qcom/ice.c),
[`qcom_scm.c`](https://github.com/gregkh/linux/blob/v7.3.3/drivers/firmware/qcom/qcom_scm.c)
and [`ufs-qcom.c`](https://github.com/gregkh/linux/blob/v7.3.3/drivers/ufs/host/ufs-qcom.c)
define the existing opt-in, firmware capability and callback contracts; this
candidate does not replace those providers. The source-check/native build,
signed package, installed kernel, running boot and physical-key stages are
recorded separately.
