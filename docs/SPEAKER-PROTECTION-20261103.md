# FourSemi speaker protection candidate

3 November 2026. POCO Pad X1 / Xiaomi Pad 7, source review and COPR source
fixtures. No new playback, calibration, kernel installation or physical
protection acceptance is established by this work.

The exact Forte ACDB metadata requires an IMCL control link between FourSemi
RX instance `0x4040` and VI TX instance `0x49fd`, on control port `0x80000000`
at both ends, with intent `0x08001231` and heap 1. The base speaker metadata
also declares an alternative peer `0x49fe`. Neither alternative is silently
substituted for the selected VI graph. Native AudioReach previously emitted
only data connections in its graph-open packet.

`0072-audioreach-control-links.patch` adds optional topology tokens 4000–4004
for a single-intent control connection. The native source preparation installs
the bounded encoder before applying that patch. Existing topologies contain
none of these tokens and retain their graph-open payload. Duplicate, partial,
zero, identical-endpoint and oversized link descriptions are rejected. The host
ACDB inspector reports control-link identities without exporting tuning data.

This is a protocol prerequisite, not an enabled VI path or a complete speaker
protection implementation. The active speaker topology, 223 gain ceiling,
four physical speaker channels, microphone graph and sample format are not
changed. The source-check RPM is a fixture receipt and must not be described
as a kernel candidate.

COPR [11251072](https://copr.fedorainfracloud.org/coprs/build/11251072)
passes for source `9590013` on Fedora Rawhide AArch64. Clang and GCC execute
the independent wire/bounds fixtures and the extracted actual topology parser;
the ACDB metadata reader also passes malformed-input and exact generic OEM
metadata checks. The produced noarch RPM installs only a validation notice.
No kernel translation unit, full kernel, playback or physical protection test
is qualified by this source-check build. The earlier11251063 failure and its
fixture correction are preserved in the central lesson journal.

The statements above describe the first IMCL-only stage. The subsequent runtime
candidate below supersedes its source implementation scope; it does not change
the physical acceptance result.

## Read-only calibration and runtime candidate

The execution environment is the tablet itself. Its existing persist audio
directory is mounted read-only and contains the binary and labelled text
calibration files. A bounded in-memory check confirmed a consistent four-channel
schema. No unit readings, unit channel order or hashes of unit readings were
saved to source, logs, RPMs or COPR. The earlier request for separate tablet
access was based on an incorrect assumption about the execution environment.

`uke-speaker-runtime` opens that directory and both files read-only, rejects
symlinks and writable filesystems, and validates file identity/timestamps across
each read. Binary CH ordinals must match the labelled text, all four positions
must be unique, and the decimal and Q12 representations must agree. CH ordinal
is preserved for the stock DSP ABI and is never treated as an ALSA slot. The
reader accepts every label permutation. It never substitutes default resistance
values or creates a calibration archive.

The stock `libfsalgocal.so` consumer was statically disassembled in COPR; it was
never executed. Its Re25 parameter is 96 bytes: four zero-initialized 24-byte
records, with the signed Q12 reading in the first word of each record. This is
different from the older OSS `0xa001` packed command. The native helper disables
core dumps, locks process memory before reading unit data, and clears temporary
buffers. Its default `--check` mode does not write ALSA controls. Explicit
`--load` requires root and the matching protected kernel interface.

The helper separately reads the exact generic Forte ACDB and verifies the whole
file hash plus each of five immutable FourSemi parameter hashes. The generic
OEM blob is not redistributed in an RPM: its redistribution terms have not been
established. No unit calibration is acquired by a build worker. A separately
provided generic file can be selected with `--acdb PATH`.

`0073-uke-fs19xx-protected-runtime.patch` and `uke-fs19xx-runtime.c` add a
512-byte transactional ALSA provisioning control, restricted by `CAP_SYS_RAWIO`.
Its read callback returns zeros. Missing, incomplete, changed, duplicate or
out-of-order provisioning fails closed. Active graphs reject reprovisioning.
The candidate validates both FourSemi identities and their IMCL link, configures
the 32-bit MFC/TDM backend and the stock VI channel types 48–51, then submits
generic parameters and per-unit Re25 before graph prepare/start.

The generated candidate graph contains MFC → FourSemi RX → TDM sink and TDM
source → FourSemi TX, with the stock control link. It restores the core FourSemi
processing and feedback path; it does not reproduce the stock logging, extra
splitter branches or every Android effect. Both subgraphs belong to backend 40
and share their lifecycle. The public PCM remains S16_LE / 48 kHz / four channels;
the DSP converts to the stock internal 32-bit transport format.

All four physical amplifier identities must register with the guard. A
configured graph allows only muted amplifier initialization; DAC unmute also
requires successful graph start. Stop, failed prepare/start/stop, service removal
and amplifier removal revoke the guard and mute/reset the amplifiers. Failed DSP
configuration clears staged calibration. Successfully closed graphs retain the
validated snapshot only in kernel RAM and reapply it before later playback.
An asynchronous amplifier initialization/PLL/unmute fault revokes the shared
atomic gate immediately and schedules group mute outside the codec mutex. A
faulted group requires fresh provisioning before it can be armed again.

The normal native preparation still selects the existing topology. The explicit
candidate preparation is `src/audio/prepare-fs19xx-runtime.sh`; it must be paired
with the generated protected topology and
`sm7675-uke-protected-speaker.dtsi`. Partial combinations cannot qualify a
protected path. No new kernel, module or topology has been installed or activated
on the tablet, and the 223 gain ceiling is retained.

COPR [11251306](https://copr.fedorainfracloud.org/coprs/build/11251306) passes
for runtime source `e88e788`. Clang/GCC and sanitizer fixtures cover all 24 label
permutations, malformed/inconsistent calibration, bounded transactions, changed
generic data and every parameter-send failure. The exact generic OEM file also
passes extraction/hash checks in the source worker and is excluded from the
SRPM. The resulting AArch64 runtime RPM enables no service. The first submission
11251285 failed before compilation on an unnecessary package-manager call;
declared COPR dependencies replaced that call.

The final reader check in
[11251348](https://copr.fedorainfracloud.org/coprs/build/11251348), source
`9ea7f23`, also rejects a valid synthetic calibration pair on a writable
filesystem. Both GCC and Clang fixtures pass; the AArch64 runtime package is
`uke-speaker-runtime-0.1-2.fc46`. No tablet calibration is used in these fixtures.

COPR [11251341](https://copr.fedorainfracloud.org/coprs/build/11251341) passes
for protected kernel source `2867896`. Clang compiles the actual `q6apm`,
`audioreach`, topology parser, LPASS DAI, FS19xx codec and new runtime translation
units against Linux 7.3.1 with the retained 122-patch native adaptation. The
protected ALSA topology compiles and decodes. Its external CPU-DAI stream names
produce the existing unresolved-stream diagnostics during standalone topology
compilation; these names are supplied by the registered kernel DAIs at runtime.
The produced check RPM is only a receipt, containing no kernel or modules.
This does not establish complete kernel linkage, DT/package admission or physical
DSP/feedback operation. Attempt 11251322 lacked the sanitizer runtime in its
worker dependencies; 11251324 found the missing explicit `linux/hex.h` include.
Both failures are corrected in the passing run.

Remaining acceptance work:

1. Complete binding/DT checks and a matched full kernel package using the
   retained device source profile. Targeted object compilation is already passed.
2. Qualify firmware parameter acceptance and actual VI sample order/continuity,
   including repeated playback, pause/resume, suspend and DSP reset containment.
3. Establish electrical/thermal/excursion limits and protection effectiveness.
   Numeric consistency of persist records is not proof of physical validity.
   The stock library's optional range configuration has not been established;
   no nominal impedance range or fallback is invented.
4. Retain the current gain limit until those checks pass. Wider public sample
   formats follow protection acceptance.

## Sources

- MiCode Uke audio `8eb0eccbc4027ae4a4987e4bced03a4381039714`, FourSemi
  `fsm_q6afe.h/.c`, `fsm_core.c` and `fs1958.c`: exact board amplifier source;
  the old APR transport and disabled Q6AFE path are not native AudioReach.
- Exact stock Forte ACDB, SHA-256
  `bd3f9b8834b80c23f86241756e263e36ddf92b2b8993ed83ff71c310af952f3e`:
  inspected as data and used for bounded in-memory runtime extraction; no
  tuning payload is redistributed.
- AudioReach engine `b38cb85a1a2543aa28aa1b27f4c380cafa5024bb`,
  `fwk/api/apm/apm_module_api.h`, BSD-3-Clause: shared APM control-link wire ABI.
- Linux stable `79a907609d53d5cd645b42c11550d295d43abf99`, AudioReach graph
  encoder and topology parser, GPL-2.0: native implementation baseline.
- Peridot `2ed9eadbecae21ef51134e556951e7305ba65f88`: adjacent AudioReach
  comparison with different amplifiers; no qualified Uke tuning substitute.
- Same-SoC OnePlus modules/DT `1138e00fee63582a0cc6a53af3286621786827b7`:
  the prior bounded source review supplies no matching FourSemi calibration
  consumer. No board or calibration values are imported from this donor.

Central lessons and physical acceptance remain in the workspace's
`uke-linux-docs` knowledge repository.
