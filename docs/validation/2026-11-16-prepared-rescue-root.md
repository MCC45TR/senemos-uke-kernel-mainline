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

Native15 (COPR 11333522, source 7167bd3c) passed on AArch64: four modes with
80 cases, two actual boot objects and both exact capability notes. The prepared
parent header is c9d89868 and remains unchanged. The text receipt's two COPR
signatures, actual source worker, complete recipe inverse and eighteen unchanged
parent assets were independently checked. This does not qualify an OS boot.

The next source check builds the original Fedora initrd with the separately
qualified builder 4f64b20 modules. It preserves the original physical-root guard
and the full make-initramfs recipe through an inverse. The codec patch retains
legacy behavior and gates new userdata-super/rescue headers on one exact aligned
kernel capability note. Four native/sanitizer modes rerun the original codec
contracts plus old, malformed, duplicate and unaligned capability refusals.
A new full kernel is not reserved by this source check.

Source check 4 (11333621) retained all four 80-case parser modes and the old
initrd measurement, then stopped because the build chroot lacked git-core.
The dependency is declared for check 5. The codec patch now owns a temporary
Git root explicitly; a source-only fixture inside an enclosing Git repository
passes the whole inverse and produces the exact intended postimage. Runtime
code and acceptance gates were not weakened to address this build failure.
