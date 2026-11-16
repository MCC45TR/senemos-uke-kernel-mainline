# Prepared rescue-root selector qualification

The running 7.3.4-3 kernel retains its original userdata root path. A separate
source check derives from all nineteen actual native14 inputs and its complete
recipe; it does not build an Image or reserve full release 4.

After every retained source preparation step, the new layer preserves the
actual ARM64 root-selector header byte for byte. It changes only that header's
include site in `uke-abl.c` to a small bounded wrapper. Normal selectors keep
the original parser. Explicit rescue selects the read-only EXT4 rescue mapper
and disables resume. An explicit userdata super flag carries a fixed 4 GiB
seed contract without changing its root, read/write mode or resume policy.
Unknown or duplicate role/seed selectors refuse without mutating the command
line. The seed is public layout data and grants no key-release authority.

Qualification covers the original prepared parser, four GCC/Clang modes with
sanitizers, and real ARM64 `uke-abl.o` and `setup.o` callers. Both original and
new capability notes are checked independently. Source checks and text-only
receipts cannot establish an OS boot, metadata authenticity, hardware sealing
or hibernation. Initramfs mapping/provisioning integration remains separate.
The source-only include transformation and complete inverse passed on the
PC without compilation. Native compilation results remain pending.
