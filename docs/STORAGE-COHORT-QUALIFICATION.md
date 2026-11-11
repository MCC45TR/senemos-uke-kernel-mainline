# Resolve encryption across the cumulative reference profiles

11 November 2026. Full kernel23 retains the native, CDSP, Waydroid and
pre-governor CDSP configurations without the eight encryption changes admitted
by source92. This qualification resolves all four existing profiles with those
same changes, using the actual COPR compiler and full23 production source.

Each profile must have exactly the eight reviewed functional changes. All six
pairwise profile differences must remain equal, including the original pogo,
network, resource-manager and governor choices. The old source inputs and
whole-config checks remain intact. A changed CPU count or lost governor must
be rejected. No old compiler configuration is supplied to a native build.

The actual final native configuration compiles dm-crypt, dm-inlinecrypt,
blk-crypto fallback, fscrypt, EXT4/F2FS integration and the current battery
driver. The battery object must retain the passive legacy observation and
root-only versioned observer. The receipt contains the resolved configurations
and object hashes; it is not a full Image, module signature or device result.

The source comparison and licenses remain those recorded in
[the encryption capability review](STORAGE-ENCRYPTION-733.md): exact Uke OEM,
same-SoC OnePlus and Linux7.3.3 revisions. The current upstream
[inline-encryption](https://docs.kernel.org/block/inline-encryption.html) and
[fscrypt](https://docs.kernel.org/filesystems/fscrypt.html) interfaces preserve
the split between native storage mechanisms and standard userspace key policy.
No donor driver or private key ABI is imported by this configuration change.

A full candidate still needs versioned handling in the retained memory,
camera, migration and boot configuration gates, real linked Image/modules,
signed RPMs and supported DNF/A-B delivery. These source checks do not enable
encryption on the installed filesystem. FDE, FBE, ICE/HIE, TEE key management,
mapper-aware boot and independent Live Recovery remain open acceptance work.
