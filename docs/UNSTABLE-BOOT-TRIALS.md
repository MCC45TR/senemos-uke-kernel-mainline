# Isolated boot regression trials

4 November 2026. POCO Pad X1, Fedora Rawhide AArch64.

The withdrawn 7.3.1-6000 trial failed to start the desktop and returned to the
accepted 7.3.1-1500 slot. No persistent panic record was available. Its exact
failed instruction and the reset behavior have not been established.

The separate `senemos-uke-linux-kernel-mainline-unstable` family retains the
withdrawn source composition with a unique `-unstable` module ABI. It owns only
its prefixed profile link. Its packages have no automatic activation scriptlet
and preserve the ordinary family's selected profile and installed modules.
The ALSA card driver and matching UCM directory use the compact per-release
identifier `uke7_3_1-REVISIONu` to fit ALSA's 16-byte field. The full kernel
release remains in the component match used by the existing audio policy.
The firmware topology lookup uses the same compact card driver name. The
initramfs inspector admits the exact numeric `-unstable` ABI while continuing
to reject malformed and foreign releases. Its actual identity fixtures and
the UCM parser run before the full native kernel build.

The first diagnostic stage skips the new CAMCC and front EEPROM boot graph
conversions. The second enables the CAMCC conversion while keeping front GENI
and EEPROM activation disabled. All driver sources, object fixtures and the
effective kernel configuration are retained. These are controlled bisection
steps, not a replacement for complete calibrated cameras and rear focus.

An independent diagnostic option retains the existing Uke 4 MiB ramoops
reservation at its OEM address. The observed OEM layout assigns 2 MiB each to
console and pmsg, leaving no dmesg dump space. This option preserves the 2 MiB
console, reduces pmsg to 1 MiB and assigns 1 MiB to panic/oops records. It refuses
an unknown layout and never relocates or enlarges the reservation. Synthetic
libfdt fixtures test the actual helper, unchanged address/extent, idempotence
and malformed-layout refusal in COPR. RAM survival across a hard reset and
capture of a real failure remain separate physical tests. A failure before
ramoops registration still cannot produce a panic record.

Layout evidence: Xiaomi's Uke `qcom/cliffs.dtsi` in kernel_devicetree commit
`94c84aeb9e517dbde546fc732033c184094c8e57`, the observed reserved-memory node,
and the [upstream ramoops documentation](https://kernel.org/doc/html/next/admin-guide/ramoops.html).

Install an exact signed candidate with DNF. Verify the accepted state and the
explicit installed bundle with `uke-kernel-update check BUNDLE` before applying
that bundle through the guarded updater. Retain the accepted slot and the
documented fastboot recovery route. A source/build pass is not a boot result;
record the running release, acceptance state, journal and pstore separately
after each physical trial. Test one staged candidate at a time.
