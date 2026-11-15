# Early HWKM native qualification

15 November 2026. [COPR 11329905][native] successfully qualified source
`f82533d3682f0ca292bfeded91de605ca76d3749` on Rawhide AArch64. This is a
source/object result. The later full27 and device results are recorded below.

The actual ICE, SCM, UFS, block-crypto, dm-inlinecrypt and CAMCC objects compiled
with `-Werror`; generation/preparation providers and UFS imports were verified.
The all38 camera adapter also compiled. Existing camera callback, fault,
semantic-mutation and GCC/Clang sanitizer modes passed. Original kmod parsed
the exact early wrapped-mode configuration. Firmware CRM refusal remains.

The actual worker, eleven new-source pins, 73 camera-source pins, generated
archives, native spec and signed receipt were audited. All 801 inherited
composition fields remain present: four tuple/provenance fields change and
six new fields extend the record to 807. Both raw configs retain SHA256
`431c839cba7c69f6c8128f67ab180ea3586b6dbc771e532adc13c91bde0e9c33`.
The full27 recipe has an exact whole-file inverse against the qualified
full26 recipe and SHA256
`4fb8122e1e00cb0eda47544a18085a7bf921d6e39043a8af60a8b6623a303bc8`.

The signed source-check RPM contains nine text/license files totaling 83,820
bytes. It has no ELF, package script or Python runtime dependency, and was not
installed. Both signatures match the pinned unstable COPR key. Its digest and
the matching source manifest are recorded in
`manifests/hwkm-early-qualified113-20261115.json` for full-build admission.
The API elapsed time is 1,745 seconds, including result transfer and signing;
it must not be reported as compiler time. Earlier source-only failures did
not create an SRPM or run the native checks; their corrected inputs precede
this qualified source.

## Full27 and device qualification

[COPR 11330023][full] built cumulative source
`2ee8b189d4657c243cdd9cfdfa64e36894f3a4e6` in 1,851 seconds; the kernel compile
stage took 1,157 seconds. The six existing runtime RPMs retain the qualified
passive-camera source, CRM refusal, gain223, hardening and previous features.
All twelve RPM signatures and 831 packaged module hashes were independently
verified. Native production checks also verified all 831 module signatures,
including unsigned, altered and wrong-key refusal controls.

The packaged Image and config match the final linked-output seals. Its actual
embedded initramfs was independently sliced using the packaged System.map;
the complete compressed archive hash matches the seal and its HWKM modprobe
configuration exactly matches source. This is packaged-output evidence, not
an assumption from the build-tree configuration.

Normal repository DNF staged 27/A while preserving the accepted 26/B and
existing recovery. All six installed RPM verifications passed. After an
authorized SSH reboot, Control reported accepted 27/A, no pending switch,
healthy system state and SELinux Enforcing. Automatic staging and the existing
local rollback preference remained unchanged. The fitted UFS profile exposes
64 hardware-wrapped-only keyslots and AES-256-XTS with 4-KiB units.

The signed [diagnostic 1.0-13][diagnostic] generated a disposable hardware key,
prepared two copies and rejected an altered copy: four key ioctls, status 0,
5,008 KiB peak RSS and released owned handles. A 128-byte private disposable
record was then retained across a second observed normal reboot. The same
record prepared successfully without regenerating a key: one key ioctl,
status 0 and 4,744 KiB peak RSS. No raw block or mapping was written and no
wrapped key bytes were copied into the evidence.

The first create/read attempts returned generic refusals despite a committed
record; their cause remains unresolved. Later traced and untraced preparation
passed without replacing that record. Fixed, nonsecret diagnostic stage labels
are being qualified to distinguish the refusing layer. These initial refusals
must not be erased or described as a production-ready transaction.

This establishes the fitted wrapped-key lifecycle and reuse across a normal
reboot. A physical power-cycle, OEM-to-Linux verified key release, encrypted
write/read, production key metadata/password recovery, userdata conversion,
protected swap and authenticated hibernation remain open. No production key
release or complete hardware acceptance follows from this receipt.

[native]: https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11329905/
[full]: https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11330023/
[diagnostic]: https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/build/11330057/
