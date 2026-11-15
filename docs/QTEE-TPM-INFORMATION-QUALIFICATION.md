# Kernel QTEE information native qualification

Subsequent signed full28 delivery and the fitted UID81 refusal are recorded
in [the kernel information result](QTEE-TPM-INFORMATION-RESULT.md). This page
describes the separate native114 qualification.

15 November 2026. [COPR11330476][native] successfully qualified source
`6bda254682039263ee75fe75b7ccbc03c3d25287` on Rawhide AArch64. This is
source/object evidence, not a deployed kernel or fitted TPM result. The
[candidate contract](QTEE-TPM-INFORMATION.md) describes the fixed request set,
root-only explicit trigger, lifetime protection and remaining limits.

The actual QTEE call, core and information objects compiled with `-Werror`.
The same production protocol core passed 23 refusal cases and all three
reported types in GCC/Clang plain and address/undefined-sanitizer modes.
Owned-object/error-output cleanup, previous-response clearing and absence of
automatic retries passed. No firmware was called or module loaded.

The actual source worker and generated recipe match the reviewed inputs.
The full source RPM was streamed through a digest and only small selected
inputs were retained on the development PC. Thirteen project inputs match;
the qualified full27 camera/HWKM archives are unchanged. Both raw configs
retain digest `431c839cba7c69f6c8128f67ab180ea3586b6dbc771e532adc13c91bde0e9c33`.
All 807 parent composition fields remain: four tuple fields change, and two
diagnostic fields extend the result to809. The planned full28 recipe has an
exact whole-file inverse against the actual full27 recipe.

Both report RPM signatures match the pinned unstable-project key. Its11
text/license files total76,712 bytes, with no ELF, executable, package script
or Python dependency. It was not installed. The machine-readable
[qualified114 record](../manifests/qtee-information-qualified114-20261115.json)
pins the source, recipe, report and signer for a later full-build admission.
The API elapsed time was1,043 seconds, including result transfer and signing;
it is not kernel compiler time.

A full cumulative kernel, final Image/module signatures, installed package
identity, accepted matching boot and an explicit fitted information request
remain required. Ordinary userspace UID81 access previously returned11; the
native fixture does not determine whether the real kernel client succeeds.
No measured boot, sealing, storage-key authority or production encryption is
established by this qualification.

[native]: https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11330476/
