# Integrate the qualified encryption configuration

11 November 2026. Native92 / COPR 11303293 compiled dm-crypt, dm-inlinecrypt,
blk-crypto fallback, fscrypt and EXT4/F2FS integration objects with eight closed
configuration changes. Those changes are not installed in kernel 22.

The data-only seed generator accepts the exact current raw configuration and
the qualified eight-option delta. It preserves every other option, including
module signatures, SELinux, UFS ICE, QTEE and filesystem support. Missing child
symbols are emitted once for Kconfig to resolve on the COPR worker. The seed
is not a resolved configuration or a native build result.

Full integration must preserve the existing native, CDSP and Waydroid reference
profiles. Each must receive the same explicitly admitted capability delta and
retain its complete comparison, including the pogo difference. The previous
memory, camera and migration records remain immutable. Extend current source
checks with reversible, versioned config handling; do not alter historical
evidence, hide symbols from comparison or present a synthetic configuration as
the one that produced the compiled objects.

Before a full candidate, resolve the seed in COPR, verify the exact delta across
all reference profiles and compile the actual battery and crypto objects with
the final configuration. Then retain full Image, module-signing, DT and RPM
checks and the normal DNF/A-B path. Combine the qualified passive protection
ABI fix when these gates are ready. No full-kernel revision is reserved here.

This enables prerequisites only. It does not encrypt the current filesystem,
unlock a volume, provision a key or activate a TEE/HWKM operation. Real FDE,
FBE, hardware-encrypted I/O, key recovery, mapper-aware boot and independent
Live Recovery remain separate acceptance work.
