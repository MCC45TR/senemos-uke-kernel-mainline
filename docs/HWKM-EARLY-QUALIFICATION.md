# Early HWKM native qualification

15 November 2026. [COPR 11329905][native] successfully qualified source
`f82533d3682f0ca292bfeded91de605ca76d3749` on Rawhide AArch64. This is a
source/object result; no candidate kernel has been installed or booted yet.

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

Next is the complete cumulative full27 Image/module/initramfs build through
the existing producer, followed by signature/package/recovery checks, normal
DNF delivery and authorized SSH reboot. The installed disposable-key probe
then tests the fitted wrapped-only profile. Persistent keys, cold-boot reuse,
encrypted I/O, authenticated hibernation and the OEM-to-Linux trust chain are
still open. This receipt grants no production key release or hardware claim.

[native]: https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11329905/
