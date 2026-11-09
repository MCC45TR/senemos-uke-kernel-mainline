# ADSP multichannel coefficient transport

9 November 2026. This source layer prepares six/eight program channels for four
protected outputs. It does not yet expand the frontend, activate a firmware
route, advertise desktop profiles or provide spatial virtualization.

The AudioReach `PARAM_ID_CHMIXER_COEFF` command replaces previous tables. The
new optional transport therefore sends three matching tables, for four, six
and eight inputs, in one 220-byte payload. The four-input table is identical
to the existing quad permutation. The existing quad API and default prepare
command stream remain unchanged. Only the qualified MFC instance is eligible;
RX/TX, amplifier identities, calibration and VI mappings are not modified.

Layouts follow ALSA interleaved channel order and actual q6apm channel IDs:

| Inputs | AudioReach identities |
|---|---|
| Four | FL, FR, LS, RS |
| Six | FL, FR, LS, RS, FC, LFE |
| Eight | FL, FR, LB, RB, FC, LFE, LS, RS |

Experimental Q14 coefficients reserve 2048/16384 for LFE in each output. Front
outputs mix their main channel at8398 and center at5938, approximately retaining
the standard square-root-of-two main/center ratio. Six-input rear outputs use
14336 for their surround channel. Eight-input rear outputs split that14336
equally between same-side back and surround channels. Each row sums to16384,
including correlated full-scale inputs. Every input has a nonzero destination.
Display rotation permutes complete output rows, not physical protection paths.

This proves only a digital peak bound. It does not establish a safe bass
crossover, excursion, loudness, gain243 or acoustic performance. The candidate
weights require firmware and physical qualification before profile activation;
they are not a claim of Dolby processing or an OEM-equivalent preset.

The protocol reference is AudioReach engine
`5773bf8e627c9857481dd338a9ec4aea4a49afd3`, BSD-3-Clause,
`modules/processing/channel_mixer/api/chmixer_common_api.h`. Its documented
replacement/fallback semantics require complete format-matched tables. Source
59/COPR11293461 independently passed the preceding actual channel-ID/mapping
checks, four compiler/sanitizer modes, historical-error refusals and the real
ARM64 AudioReach composite. That is a prerequisite, not firmware acceptance.

Native checks for this layer exercise the actual packet encoder and command
transport, all four rotations, exact layout/size and old quad packet identity,
correlated full-scale rows, center/LFE/back/side coverage, every invalid buffer
size, invalid target/map, allocation failure and synchronous DSP errors. A
deliberately missing LFE coefficient must fail. The freshly built ARM64 composite
must export both old and new APIs. No local tablet compilation, CPU sample
mixer, new runtime package, daemon or poll loop is introduced.

Remaining work: frontend6/8 constraints and ALSA channel-position controls,
protected backend format selection and rotation rollback, prepare/STOP/reopen,
firmware coefficient acceptance, original UCM/PipeWire profile integration and
physical per-channel/suspend/recovery tests. These gates remain separate from
source and build results.
