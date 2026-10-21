# Root-selector capability declaration

The source boot producer emits one allocated ELF64 note through Linux's
`ELFNOTE64` helper. It declares the bounded argument parser ABI; it does not
enable private VRR or establish display/boot qualification.

| Field | Version 1 |
| --- | --- |
| Byte order / alignment | Little-endian / four bytes |
| Note name | `UKE` including its terminating NUL; namesz 4 |
| Type | `0x554b4501` |
| Descriptor | `root-selector-v1;userdata=f2fs;slot=a,b;vrr-min=0,30` including its terminating NUL; descsz 53 |
| Padding / total length | Zero padding to four bytes / 72 bytes |
| Boot manifest property | `root_selector_capability=uke-elfnote-v1` |

`__used` in the upstream helper forces compiler emission. The ARM64 kernel's
`RO_DATA`/`NOTES` linker rule retains `.note.*` through `KEEP`. The note is emitted
by the same header as the parser in the Uke ABL translation unit. Source and
package configuration checks remain necessary; the declaration is not code
attestation.

The host producer checks exactly one complete aligned note in the final raw
Image before creating either boot wrapper. `check-root-capability.sh` checks
header sizes, name, type, descriptor, NULs and padding, rejecting absent,
duplicate, malformed and unsupported declarations. Parser text or descriptor
text alone is insufficient. A consumer must also verify the signed package,
matched manifest, unchanged extracted Image and normal update/rollback gates.
No kernel hash allowlist substitutes for those checks.

The source lock records the same declaration. The native package check runs
`root-selector-note-contract.sh` with its prepared kernel source and boot recipe
lock. It uses the actual Linux ELFNOTE macro, LTO and linker garbage collection,
plus rejection fixtures. The host and AArch64 object/link fixtures do not qualify
a complete boot image; the coordinated kernel build must pass the final Image
check before delivery.

The boot RPM requires both `uke-kernel-update >= 1.1.2` and
`uke-kernel-update(guarded-automatic) >= 1` as ordinary, lasting dependencies.
The guarded consumer must be present when the kernel's post-transaction hook
runs and remain installed afterwards. A `Requires(posttrans)` declaration alone
does not provide a lasting requirement or order package installation. The
consumer must apply its global/profile gate without relying on another
package's post-transaction initialization. This source change is reserved for
the next coordinated kernel release; published release-16 RPMs are unchanged.
