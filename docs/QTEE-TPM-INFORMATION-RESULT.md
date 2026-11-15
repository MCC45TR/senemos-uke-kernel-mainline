# Kernel QTEE information result on Uke

15 November 2026. Cumulative kernel **7.3.3-28-unstable** was built in
[COPR11330530][full], audited, installed through the configured signed RPM
repository and booted on POCO Pad X1. Native health accepted slot B; kernel27
remains bootable in A. SELinux Enforcing, automatic staging and the existing
local rollback preference were preserved. The [qualified28 record][record]
pins the build and fitted result.

## Fitted service result

Before the explicit request, the root-only cached parameter reported
`requested=0`, `present=1`, with zero invocation attempts and vendor queries.
One write of `1` returned successfully in 24 ms end to end. The resulting
report was:

```text
schema=1 requested=1 busy=0 present=1 stage=3 transport=0 remote=11 malformed=0 kind=0 major=0 minor=0 invocation_attempts=2 vendor_queries=0
```

The existing privileged kernel registration obtained an environment, but
opening UID81 failed at the service stage with remote status11. No version,
type, TCG, Startup, PCR, NV or key command was sent. Another cached read kept
the counts unchanged. System health remained running and Enforcing; the
protected running-image check passed. No test key record remains.

This is the same numeric UID81 refusal previously observed with ordinary
userspace credentials. It rules out treating ordinary registration alone as
the missing access step. The fitted firmware's status11 meaning remains
unclassified. It does **not** establish TPM absence, a TPM version, a usable
sealing service or verified-boot-bound storage-key release. No TA loader or
firmware mutation was attempted. Repeating the request or removing the user
ioctl restriction is not justified by this result.

## Build and delivery evidence

[Native114][native] qualified the production core's 23 refusal cases and all
three types in four compiler/sanitizer modes, plus three actual QTEE AArch64
objects with `-Werror`. Full28 retains the actual full27 sources, configuration,
camera/HWKM changes and existing six runtime package families. The immutable
[candidate contract][contract] is the source-preparation snapshot; this page
records subsequent package and device evidence without changing its pins.

The actual full28 source recipe, all 13 admitted inputs, retained signed native
report, both raw configs and 809 composition fields were checked. All six RPMs
have 12 trusted signatures. The 831 packaged module hashes were checked
independently; COPR verified 831 module signatures and refused unsigned,
tampered and wrong-key controls. Image/config seals, both boot-image kernel
slices and the actual embedded HWKM configuration match.

Normal DNF installed five kernel packages and upgraded singleboot, downloading
115 MiB and adding 283 MiB without removing earlier kernels. All six installed
RPM verifications and Image/config hashes matched. The updater wrote, synced
and read back28/B while preserving accepted27/A. A real SSH reboot then
established accepted28/B with no pending switch. API elapsed time was 2,134 s,
including transfer/signing; kernel compilation was 1,195 s.

## Remaining work

Investigate the fitted secure-firmware service contract or another legitimate
hardware sealing provider using exact OEM and primary upstream sources.
Hardware-generated wrapped-key reuse across a normal reboot was demonstrated
on kernel27; that separate result supplies no accepted-boot policy. OEM-to-Linux
trust, production automatic release, physical encrypted I/O, data-preserving
conversion and protected authenticated hibernation remain open. No production
storage-key authority or complete hardware acceptance is granted by kernel28.

[full]: https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11330530/
[native]: QTEE-TPM-INFORMATION-QUALIFICATION.md
[contract]: QTEE-TPM-INFORMATION.md
[record]: ../manifests/qtee-information-qualified28-20261115.json
