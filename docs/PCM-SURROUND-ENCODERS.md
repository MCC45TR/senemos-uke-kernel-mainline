# PCM transport for protected surround input

10 November 2026. On kernel7.3.3-12, original PipeWire1.6.11 ACP creates the
six/eight-input UCM profiles but rejects them when both AudioReach PCM encoders
refuse more than four channels. The frontend, topology and MFC tables alone
therefore do not establish working surround playback.

The transport patch accepts bounded PCM counts1..8, using the actual
AR_PCM_MAX_NUM_CHANNEL capacity. Sparse physical maps must contain enough
nonzero entries for the declared logical count. Validation occurs before packet
allocation or submission. Compressed-format validation and dispatch remain
unchanged. Existing S16, packed/unpacked S24 and S32 representation is retained.

Both format headers now state the logical PCM payload length. The shared-memory
header previously counted the enclosing parameter TLV; PCM output length also
included alignment bytes. The AudioReach media API explicitly excludes both.
The enclosing packet remains aligned and its padding remains zero. Fixtures
check actual extracted C encoders, offsets, complete maps, logical/outer lengths,
all padding, allocation/send errors and compressed dispatch. Historical max4,
wrong-length and incomplete-map regressions must fail independently. A fresh
AArch64 AudioReach composite and frontend compile is required in COPR.

This layer does not change amplifier gain223, four physical outputs, calibration,
VI, routing, profile selection, DMA mappings or stream ownership. A prepare error
can leave host fragment descriptors allocated in the inherited frontend; its
cleanup remains a separate lifecycle investigation. Do not release DSP-owned
DMA to hide EBUSY or ambiguous START/STOP timeouts. A successful source proof is
not firmware acceptance, audible six/eight-input downmix or spatial virtualization.

Primary comparisons, inspected without modifying reference sources:

- Uke OEM audio8eb0eccbc4027ae4a4987e4bced03a4381039714, GPL-2.0-only,
  `asoc/codecs/fs19xx/fsm_core.c`: legacy stereo CHS selection, not a native
  six/eight-input AudioReach transport or portable four-output renderer.
- Linux7.3.3 d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd, GPL-2.0,
  `sound/soc/qcom/qdsp6/audioreach.{c,h}`, `q6apm.{c,h}`, `q6apm-dai.c`:
  frontend max8 versus both encoder max4; actual channel-map capacity8;
  fragment descriptors and DMA mapping have distinct ownership.
- AudioReach engine5773bf8e627c9857481dd338a9ec4aea4a49afd3, BSD-3-Clause,
  `fwk/api/modules/media_fmt_api_basic.h`, media_format_t and
  param_id_pcm_output_format_cfg_t: logical payload excludes alignment bytes.
  Public API compatibility does not prove every fitted firmware module accepts
  a particular PCM graph.
- Original alsa-lib1.2.16.1 a7babcb8e6361719bf18fa96f11354d125447500 and
  PipeWire1.6.11 `spa/plugins/alsa/acp/alsa-ucm.c`: semantic UCM import and
  actual PCM probing are separate from plain syntax parsing. Stock packages
  remain the consumers; no fork, extra runtime RPM or service is required.

The pinned donor inventory does not establish a same-SoC native surround renderer.
Do not copy another board's calibration or proprietary algorithm. Permanent UCM
semantic-name repair is independently qualified by source69 and must accompany
later full delivery. Original HiFi/microphone/DP, failed prepare/STOP recovery,
rotation and actual firmware acceptance require recoverable device tests.
