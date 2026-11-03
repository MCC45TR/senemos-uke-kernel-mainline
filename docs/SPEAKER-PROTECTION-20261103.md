# FourSemi speaker protection prerequisites

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

Remaining prerequisites, in implementation order:

1. Establish the exact active FourSemi RX/TX parameters and firmware contract,
   including the selected TDM TX media format and voltage/current channel
   ordering. A module ID or a generic Qualcomm protection graph is insufficient.
2. Qualify the four per-unit Re25 values and their amplifier identities. The
   stock calibration consumer uses four 24-byte records; the older OSS packed
   structure is a different ABI. No default resistance or channel order is
   invented, and persist remains read-only.
3. Bind playback and feedback lifecycle, control link, calibration and DSP
   readiness before amplifier unmute. Contain DSP reset, timeout, start/stop
   failures, suspend and removal. Observing feedback alone is not proof of
   closed-loop protection effectiveness.
4. Build a matched kernel candidate in COPR and qualify bounded physical
   feedback/protection behavior before widening the playback sample format.

## Sources

- MiCode Uke audio `8eb0eccbc4027ae4a4987e4bced03a4381039714`, FourSemi
  `fsm_q6afe.h/.c`, `fsm_core.c` and `fs1958.c`: exact board amplifier source;
  the old APR transport and disabled Q6AFE path are not native AudioReach.
- Exact stock Forte ACDB, SHA-256
  `bd3f9b8834b80c23f86241756e263e36ddf92b2b8993ed83ff71c310af952f3e`:
  metadata only; no tuning payload is redistributed.
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
