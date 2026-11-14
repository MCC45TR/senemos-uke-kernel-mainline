# Six/eight input stream integration

9 November 2026. The preceding channel maps and bounded MFC coefficient
transport remain prerequisites. This layer connects them to the dedicated Uke
speaker frontend while leaving the protected physical backend at four channels,
48kHz/S16 samples in its existing32-bit transport slots.

The Uke/SM7675 playback FE with graph ID1 accepts only4,6,8 channels and exposes
fixed ALSA channel-position controls matching `snd_pcm_std_chmaps`. Other FE
IDs, capture and other boards remain unchanged. The backend prepare reads the
connected dynamic FE's actual hw_params through ASoC DPCM. It rejects absent,
foreign, unsupported-format and conflicting shared layouts. It never obtains
the input count from the four-channel backend fixup or a display-policy value.
All existing S16_LE/S24_LE/S32_LE frontend formats remain accepted; the existing
MFC converts them before the unchanged16-bit physical backend. Input container
width is not a claim of additional DAC resolution.

Prepare records that input count under the existing quad/graph mutex. Quad
input keeps the existing coefficient API and default-zero prepare command
stream. Six/eight input installs all three MFC tables, including at zero
rotation. Live rotation uses the same table family and existing rollback/fault
boundary. Shutdown clears the cached input count; a failed prepare closes the
graph and retains the fault path. Amplifier/RX/TX/VI/calibration identities and
gain223 remain physical and unchanged. No sample processing runs on the CPU.

This source candidate does not yet alter the compiled topology or publish UCM
surround verbs. Full delivery must widen only the dedicated FE capabilities,
verify the compiled topology's unchanged protected graph and expose the actual
6/8 path through original ALSA/UCM/PipeWire. Firmware must accept the input
format and coefficient rules; per-channel sound, LFE/headroom, rotation,
STOP/reopen, suspend and recovery need physical qualification. A downmix does
not establish spatial virtualization, Dolby support or gain243 safety.

Primary references remain Linux7.3.3
`d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`, GPL-2.0,
`include/sound/soc-dpcm.h`, `include/sound/pcm.h`, `sound/core/pcm_lib.c` and
`sound/soc/qcom/qdsp6/q6apm-dai.c`; AudioReach engine
`5773bf8e627c9857481dd338a9ec4aea4a49afd3`, BSD-3-Clause, channel-mixer API.
The exact OEM amplifier route/calibration remains the established Uke graph;
no other-board native surround renderer is established by the donor inventory.
Native actual-callback fixtures and fresh ARM64 FE/LPASS objects are required;
their success is separate from full linkage, package and physical admission.

Source63/COPR11293692 failed699s while compiling the new controlled FE
fixture: raw UAPI annotations were not defined and its model reused the real
hw_params tag. The correction supplies normal annotation semantics and a
distinct controlled-provider tag. An early GCC/Clang syntax-only preflight
now precedes cumulative preparation. Hardware code and every runtime assertion
are retained; the final controlled callbacks and real ARM64 objects remain
required. No support or physical acceptance follows from the failed fixture.

The early64 preflight11293726 stopped82s after an unsigned-count/negative-errno
conditional triggered -Werror=sign-compare. The implementation now returns
-ENOLINK in an explicit branch before returning the bounded channel count.
No warning is disabled and no acceptance assertion is removed.
