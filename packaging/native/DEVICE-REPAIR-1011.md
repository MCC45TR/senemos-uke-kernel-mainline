# Device repair source recipe

2 November 2026, Fedora Rawhide AArch64. `copr-device-repair1011.sh` prepares a
fresh 7.3.1-1011 ABI from the retained production source used by accepted
7.3.1-1010 (COPR11240834, source517030ed). It verifies the parent SRPM hash,
retains upstream/adaptation/boot inputs byte-for-byte and repeats the qualified
panel fixture correction. Driver and DT sources are unchanged.

The existing kernel package requires the updated A/B writer and imports a
hash-admitted local VPU candidate into the new kernel's versioned firmware
directory before normal policy-gated staging. Public packages contain no OEM
video firmware. The accepted kernel's firmware lookup remains separate.
Package ownership includes the locally generated file for later removal.

The recipe runs only in COPR; it must not run on the tablet. Automatic-update
configuration is preserved and no reboot is requested. Build success does not
prove local firmware authentication, video streaming, boot acceptance or any
other hardware result. Those require separate device measurements.
