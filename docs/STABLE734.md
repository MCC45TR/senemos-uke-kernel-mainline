# Linux 7.3.4 cumulative preparation

15 November 2026. The latest explicitly requested next runtime tuple is
`7.3.4-2-unstable`. Failed full attempts retain that tuple; only successful
full releases advance it. Native source-check counters are independent and
do not establish that a corresponding runtime kernel was built or installed.
Fresh COPR history contains no full7.3.4 release. The user explicitly selected
release2 as this series' initial full version; no full1 success is claimed.
`next-planned-full` reads that initial value from the reviewed release plan,
retains it after failed attempts and advances only after success. Existing
series keep their initial1 and all gap/active-build/downgrade checks.
This source preparation does not reserve or build a full kernel. It preserves
the actual complete full28 source RPM from COPR11330530, rather than rebuilding
an older generic recipe with a new version number.

The Linux stable archive is SHA256
`b11b6df8295e8e991ff040b71aaa4994a8b55caa23b6b092907f195b5840fd1f`.
Its detached signature verifies against stable maintainer fingerprint
`647F28654894E3BD457199BE38DBBDC86092693E`; the signed tag resolves to
`7595a62d45ee1a2297eafa5f2ef5d0a45142d84d`. The NVMEM core source seal is
unchanged from7.3.3. The incremental upstream change contains1109 paths;
DSI-host and UFS changes require native compilation with the retained stack.

The source worker verifies the parent RPM/spec and archive manifests, retains
all hardware feature fields, all configuration bytes and unrelated inputs,
retargets the compact ALSA identity, and changes only16 admitted version helper
copies with whole-file inverse comparison. The recipe keeps all existing
preparation and behavioral checks. Unknown patch or source-seal differences
must fail and be reviewed; this version update does not remove those checks.
COPR then compiles affected native units, the native RGB owner and the complete
Iris composite without an Image or firmware
operation. Source and native qualification remain pending.

The first check11331348 stops in source preparation at adaptation0056:
Linux7.3.4 changed both PMIC altmode notification dispatches to the freezable
queue. The retained Uke patch replaced those dispatch sites with its bounded,
generation-tagged queue. The revised adaptation carries the upstream freezer
policy into both normal event and service-loss queueing, preserving the Uke
consumer ACK ordering, lifetime, quarantine and teardown. A four-line whole
patch inverse and actual source application pass; the real PMIC object must
reference `system_freezable_wq`. No event or power guard is removed.

The second check11331363 reaches the AudioReach unmap change. Upstream now
contains most of adaptation0085 and changes its internal producer argument
from child device to APM instance, while also freeing mappings during component
removal. The rebased patch retains the Uke missing-graph refusal and leaves
upstream teardown, token and error handling intact. Existing fixture calls now
resolve the same APM instance; all assertions remain. Adaptation0091 moves the
new hardware-position reset to successful fresh allocation, preserving both
the upstream reset and the Uke repeat/allocation-failure cursor contract.
The buffer fixture additionally checks those reset and preservation cases.
All122 adaptation patches apply to the signed7.3.4 source in a small PC text
rehearsal, without compiling. Complete preparation and native object results
remain separate COPR gates.

Check3/11331386 passes all122 adaptations and the retained early behavioral
controls, then refuses the old DSI whole-file seal. The stable release adds
`drm_gpuvm_put()` and clears its pointer on TX allocation failure. A small
source rehearsal applies the exact retained DSI display stack, reverses only
those two signed upstream statements and recovers the complete original
retirement60 SHA256. The updated734 seal is868b5639; every other sealed source
and the whole-file check remain. This preserves the upstream lifetime fix
instead of reverting it to satisfy an old checksum.

Check4/11331415 reaches Iris. Its734 IOVA declarations and power-off ordering
change two patch contexts; the rebases retain those upstream changes with
whole-patch inverses. The frame-interval adaptation also preserves the new
standard continuous interval type and its unused step denominator, while
retaining exact codec limits and conservative bandwidth arithmetic. All21
Iris patches apply in a PC text rehearsal. Native fixtures still check their
power, firmware, DMA and error lifecycles; the full Iris composite is added to
the native object gate. No firmware call or video operation occurred in this
rehearsal.

Check5 attempt11331483 stops during source generation before producing a
source RPM: the transformation incorrectly expected Iris patches in the boot
helper archive. Those patches and their manifest belong only to the native
profile; both archives retain a shared capability fixture. The correction
asserts that exact ownership instead of adding a duplicate stack. Source
counter5 remains available for that retry; this does not consume runtime release2.

The retry11331501 creates source RPM7.3.4-5, then stops at an unrelated torch
preparation dependency. The generic checkout's preparation contains older
standalone torch additions absent from the complete full28 recipe. The LED
overlay now retains the actual full28 preparation and inserts only its new
battery fixture call, with an exact preimage and whole-file inverse check.
No torch, flash-thermal or other hardware protection is removed from full28.
Because check5 produced a source RPM, changed source-check bytes use counter6;
the pending full runtime release remains7.3.4-2.

The same candidate stages the requested native battery LED policy and actual
worker fixtures. It adds no runtime bridge package. The existing Control RGB
status reader needs the appended mode label before delivery; source success
alone does not close that compatibility or physical LED gate.

The fresh KDE image currently boots full28 with original Fedora audio providers.
Supplying the missing exact generic DSP data restores the normal HiFi profile;
a notification succeeds and audible speaker output is confirmed. Permanent
out-of-box data delivery and restart, microphone and channel checks remain open.
Read-only KDE observations show VRR incapable, automatic brightness enabled,
adaptive backlight modulation supported at level1 and PowerDevil active with no
restarts. Preserve the backlight and ALS interfaces during native VRR work.

The requested final kernel still needs native VRR/data integration, cumulative
qualification, a complete signed build, normal DNF staging and physical tests.
RPM/module signatures do not establish an OEM-to-Linux verified boot chain.
No OEM bootloader write, relock or speculative enrollment is part of this
preparation. Rescue, DTBO/vendor_boot, commissioning USB, hardware-bound storage
keys, encryption and hibernate retain their separate open acceptance gates.

Check6/11331550 passes the new RGB policy and actual battery-worker fixtures,
including exact red fades, finite blue pulses, two-point rearm, telemetry
faults, event ownership and unchanged PWM/camera limits. It then stops at the
old PCM worker whole-file seal. Stable734 fixes the ring pointer to report the
true start of a completed lap. Reversing that exact signed upstream delta
recovers the full oldacb1773a preimage; the original worker patch applies with
the fix retained. Before/after seals become d3c99fd9/54c1b3fc with complete
helper inverses, retaining every worker assertion and refusal check.

The next candidate also carries native VRR initialization on the exact
Uke/SM7675 catalog and bonded video topology. Explicit zero and saved positive
floors remain authoritative; unsupported parameters do not change that state.
The existing O82-42 DT, DSI/DSC, mode and atomic checks still decide capability;
all programming, paired rollback, backlight modulation and ALS paths remain.
The original API block is checked through a whole-file reverse of this one
admitted late layer, alongside actual new initialization/parameter fixtures.
The historical parent default field describes the retained earlier layer;
the new native-default layer records the requested boot behavior separately.
Original KDE sees the standard DRM properties; no compositor fork is added.
Physical capability visibility, cadence, flicker and touch still need Uke tests.

The user additionally requests livepatch in this same pending full release.
[Signed livepatch preparation](../src/livepatch/README.md) adds only the final
LIVEPATCH setting and a pinned public certificate, preserving mandatory module
signatures and all other protections. Source6 predates these changes. The next
COPR check must compile their actual native objects; no signed patch load,
camera image, new kernel installation or physical acceptance is yet claimed.

Check7/11331595 reaches the cumulative battery layers, then rejects an old
whole-file seal. Stable734 adds deduplicated charger-online notifications for
the SC8280XP shared path. The Uke fixed-band, event, standard getter, demand
and observation layers all retain that upstream code. Each of their four
complete source stages recovers its old hash when only the signed upstream
delta is reversed. Five contracts receive those admitted before/after hashes
with complete JSON inverses; no charging writer, threshold, event or assertion
changes. The actual battery and PCM frontend objects join the native build gate.

Check8/11331623 passes the complete inherited source preparation, including all
battery stages. The late VRR preimage check correctly rejects an incomplete
local rehearsal: it omitted the already retained MST stream-depth layer. The
actual recipe had that feature throughout. The rehearsal now includes its exact
qualified patch before measuring the whole encoder pre/post images, and the
native gate adds the actual MST object. No MST or display feature is removed;
the VRR patch still changes only native initialization and explicit policy
precedence. The next check must qualify the new functions and actual objects.
