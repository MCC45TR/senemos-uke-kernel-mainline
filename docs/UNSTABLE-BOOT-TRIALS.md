# Isolated boot regression trials

4 November 2026. POCO Pad X1, Fedora Rawhide AArch64.

Kernel development and candidate updates use the unstable family. Update the
normal stable family only on an explicit manual request after physical
validation. A passing build or test does not authorize stable promotion.

The withdrawn 7.3.1-6000 trial stalled at the POCO/Xiaomi firmware logo. Manual
Fastboot slot selection restored accepted 7.3.1-1500. No persistent panic
record was available. Its exact
failed instruction and the reset behavior have not been established.

The separate `senemos-uke-linux-kernel-mainline-unstable` family retains the
withdrawn source composition with a unique `-unstable` module ABI. The initial
7006–7008 candidates used a prefixed profile link and coexisted with ordinary
mainline. Starting with candidate 7200, every unstable subpackage conflicts
with the ordinary core and profile packages. Ordinary packages require their
core, so this excludes both complete and partial opposite-family installations.
The optional unstable singleboot package owns the normal selected profile link.
Keep automatic seamless staging enabled across DNF installs and updates.
Rollback is a separate persistent local choice; package defaults remain
enforced. Native version 1.8.71 separates off-mode health acceptance from
staging and preserves the local choice during install and reinstall. DNF
transaction hooks may prepare the selected candidate, while reboot remains a
separate operation. Do not disable automatic policy as a trial workaround.
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

## Published candidates and validation

| Kernel release | Camera conversion stage | Panic allocation option | COPR build |
| --- | --- | --- | --- |
| 7.3.1-7006-unstable | Skip CAMCC and front EEPROM | Original OEM layout | [11253472](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11253472/) |
| 7.3.1-7007-unstable | CAMCC only | Original OEM layout | [11253473](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11253473/) |
| 7.3.1-7008-unstable | Skip CAMCC and front EEPROM | 1 MiB panic/oops | [11253587](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11253587/) |
| 7.3.1-7200-unstable | Skip CAMCC and front EEPROM | 1 MiB panic/oops | [11259638](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11259638/) |
| 7.3.1-7300-unstable | Skip CAMCC and front EEPROM; read-only RTC counter | 1 MiB panic/oops | [11259919](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11259919/) |
| 7.3.1-8101-unstable | CAMCC only; read-only RTC counter; front EEPROM gated | 1 MiB panic/oops | [11260006](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11260006/) |

Initial candidates 7006–7008 passed Fedora Rawhide 46 AArch64 builds and RPM checks. Signed RPMs
were installed through DNF and passed read-only bundle admission. Initial
installation left the accepted 1500 selection unchanged. A subsequent explicit
7008 trial reached userspace, but the PMK8550 RTC remained deferred. The health
observer rejected the trial after its 90-second window. The native fallback
selected accepted slot B and requested an orderly reboot into 1500. This is an
observed userspace health fallback; neither healthy 7008 acceptance nor recovery
from an early bootloader hang is established. Pstore remained empty.

The boot-integration policy candidate adds `rollback-enforced` (end-user
default), `rollback-permissive` (observe without automatic fallback), and
`rollback-off` (skip automatic acceptance/fallback). Configure them with
`uke-control set MODE` and inspect with `uke-control rollback status`.
Development off mode permits an explicitly checked family replacement after
old RPM removal, using the recorded accepted slot hash. Retaining old slot
bytes without the matching modules is not a qualified full rollback. Image,
package, firmware, UFS and transactional write checks still apply. Normal
enforced same-family updates require the accepted installed cohort.

A subsequent physical boot identifies 7.3.1-7200-unstable in slot A with off
persisted and the accept unit exiting successfully without fallback. The RTC
is still deferred; this does not establish a healthy accepted trial. Candidate
7300 restores the read-only RTC counter contract and keeps the unqualified
firmware-offset property inactive. Its rationale and validation limits are in
[RTC counter admission](RTC-COUNTER-GATE.md). The accepted B/1500 partition
must remain unchanged during this investigation.

Candidate 7300 passed source-worker RTC fixtures, prepared-driver fixtures, the
full AArch64 build and RPM checks. DNF installed its five kernel packages and
native bundle admission passed. The 7200 profile, both raw slot hashes,
protected trial state and off mode stayed unchanged. No 7300 physical boot,
RTC binding, wake alarm or UTC persistence is established. Current 7200 remains
an unaccepted trial; candidate installation does not authorize healthy approval
or replacement of the accepted stable image.

Candidate 8101 passes the full native build, CAMCC/CRM and RTC fixtures and
834 module-signature checks. It uses RTC producer
`00ebf622ca473b9b7a799b2f531b4871ddc70497` with CAMCC stage 1 enabled.
Front GENI/EEPROM, sensor and capture graph activation remain disabled.
Initial five-package signed DNF delivery and read-only admission on 7200 left
the running cohort, profile, images and protected state unchanged. Updater
1.8.90 now watches the containing profile directory. Signed DNF delivery invokes
automatic preparation and verifies 8101 in A, preserving B and the boot disk's
non-target GPT entries. A profile-only DNF reinstall invokes the pending-reboot
guard with unchanged images, protected state and local off. Current execution
remains 7200; the matching 8101 boot, real controller ownership and camera
operation remain unqualified. A separate CAMCC-only 7300 build 11259915 reused the RTC
candidate's NEVRA and is withdrawn from delivery. Do not mix those artifacts
or identify their contents solely by version; 8101 has a distinct identity.

The separate `uke-boot-graph-audit-unstable-0.1-3` tool, built in COPR 11253683
and installed through DNF, executed both retained 6000 camera helpers on a RAM
copy of the current FDT. CAMCC and front EEPROM each returned zero. This does
not establish admission of the original failed-boot input or successful driver
probing. The firmware-logo stall's exact cause remains unproved.

Install an exact signed candidate with DNF. Verify the accepted state and the
explicit installed bundle before applying it through the guarded updater.
For a normal accepted baseline use `uke-kernel-update check BUNDLE` and the
existing apply operation. For a recorded, booted and unaccepted unstable A
trial in rollback mode off, version 1.8.60 adds explicit `check-trial BUNDLE`
and `replace-trial BUNDLE`. Its source is
[documented with the updater](https://github.com/MCC45TR/uke-linux-hardware-support/blob/8eb0c4d/uke-boot/DEVELOPMENT-TRIALS.md).
Remote fault-injection tests, signed DNF delivery and read-only admission on
7200 pass. The later [1.8.90 directory-trigger fix](https://github.com/MCC45TR/uke-linux-hardware-support/blob/b5f1adb991bc39743cea75ebd5b6e4292592b354/uke-boot/README.md)
passes actual DNF preparation of A and profile-only reinstall idempotence.
Power-loss recovery and the first matching camera boot remain unqualified.
This narrow operation preserves B bytes/flags and UFS selection, quarantines A
before writing, verifies the result and leaves it unaccepted. It creates no
full-image backup and requests no reboot. Verify the exact candidate and a
recoverable observed trial before replacing A. Retain the accepted slot and the
documented fastboot recovery route. A source/build pass is not a boot result;
record the running release, acceptance state, journal and pstore separately
after each physical trial. Test one staged candidate at a time. With seamless
policy enabled, DNF can prepare the selected candidate before it returns.
After current-A preparation, `check-auto` reports the pending reboot without
repeating the image write. The old running Image no longer matches either raw
slot until the new boot, so read-only status may leave the current slot unknown;
that does not establish a new boot or healthy approval.
