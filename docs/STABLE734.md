# Linux 7.3.4 cumulative preparation

15 November 2026. The requested next runtime tuple is `7.3.4-1-unstable`.
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
COPR then compiles ten affected native units without an Image or firmware
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
