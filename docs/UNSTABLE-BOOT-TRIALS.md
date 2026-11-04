# Isolated boot regression trials

4 November 2026. POCO Pad X1, Fedora Rawhide AArch64.

The withdrawn 7.3.1-6000 trial failed to start the desktop and returned to the
accepted 7.3.1-1500 slot. No persistent panic record was available. Its exact
failed instruction and the reset behavior have not been established.

The separate `senemos-uke-linux-kernel-mainline-unstable` family retains the
withdrawn source composition with a unique `-unstable` module ABI. Its optional
singleboot subpackage owns a prefixed profile link. The candidate packages have
no activation scriptlet and preserve the ordinary selected profile and modules.
The installed updater can still run its transaction file trigger; review the
actual DNF transaction and selected profile rather than relying on candidate
scriptlet absence alone. Explicit bundle checks do not require installing the
optional singleboot profile.
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

## Return to B/1500 between camera candidates

Conduct physical trials with an operator present and the existing fastboot
recovery route available. Keep the native health and fallback services active.
The following sequence is supported by updater 1.8.39 source and its COPR
fixtures; it is not a successful physical trial receipt.

The [startup orchestration](https://github.com/MCC45TR/uke-linux-hardware-support/blob/d03d854032dd7c0b011ac1be2ff1089850af0403/uke-boot/src/kernel-update.cpp)
accepts a healthy running trial before checking automatic activation policy.
With both automatic policies enabled and the ordinary default still pointing
to 1500, a successful A trial can therefore be accepted and then prepare 1500
in B for the next boot. Disabling automatic activation does not disable health
acceptance. Boot health acceptance does not qualify camera operation,
calibration, focus or a complete mode.

The inactive-slot writer verifies the accepted image and skips image writes
when the destination already equals the installed return bundle. This can
retain the existing B/1500 bytes during a return, while GPT flags, UFS selection
and protected update state still change. Verify actual slot bytes and state;
the unchanged default-profile symlink alone does not identify the selected
physical slot or prove this condition.

| Point in a successful trial | Required observation before continuing |
|---|---|
| Start on B/1500 | Running and accepted B/1500, stable state, no outstanding candidate, matching installed baseline |
| Prepare one camera candidate in A | Exact bundle admitted; original B/1500 bytes retained; candidate and selection recorded |
| Boot the A candidate | Observe its actual running release, health, provider state, journal and pstore. Acceptance may now name A; automatic policy may already have prepared a B/1500 return |
| Return to B/1500 | Verify the prepared return and reboot to it. Confirm running and accepted B/1500, stable state and no outstanding candidate |
| Prepare the next camera candidate | Repeat only after the B/1500 return is verified |

Applying another camera candidate while running an accepted A trial targets
inactive B and can replace the original recovery image. Do not supersede a
pending B/1500 return with the next camera candidate. First complete and verify
that return, then apply the next candidate to A.

If automatic activation is disabled or no return was prepared, retain the
existing policy and inspect the reason. From a healthy, accepted A trial, the
existing explicit return path is:

```sh
uke-kernel-update check /usr/lib/senemos/kernel-updates/7.3.1-1500
uke-kernel-update apply /usr/lib/senemos/kernel-updates/7.3.1-1500
```

Use this only after the read-only check succeeds and the current protected
state is understood. Verify the selected return before rebooting. Use the
inactive-slot operation above; `apply-current` is a different path that creates
an image backup. No new partition image backup or service mask is needed for
the reviewed sequence. Failed health, return admission or slot verification
requires recovery/review before another candidate.
