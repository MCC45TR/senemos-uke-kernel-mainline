# Four-channel speaker rotation

Date: 8 November 2026. Cumulative source candidate; not installed. Running
kernel7.3.3-7 retains the previous implementation. Native source44 passes41 route and24 LPASS cases in four compiler/sanitizer
modes, then fails the real ARM64 compile on a current-task macro collision and
the const DAI callback signature. Both are corrected. Added machine callbacks
and concurrent close tests require a new complete source45 proof.

The operator's KDE speaker test reports that front-right remains at a fixed
physical speaker after portrait and inverted rotation. This concerns speaker
playback, not microphone capture. Four logical channels must follow the screen
corners, rather than only swapping stereo sides.

On7.3.3-7 with original KWin6.8.2, a bounded display configuration test observes
Wayland transforms0/1/2/3 and matching aggregate/per-amplifier ALSA enums.
No sound or volume command is used. The active output modes remain native
3200x2136 at144Hz in every transform. The compositor-to-control path works in
this test; it does not establish physical channel routing.

Exact Uke OEM audio commit8eb0eccbc4027ae4a4987e4bced03a4381039714,
`asoc/codecs/fs19xx/fsm_core.c: fsm_swap_channel`, chooses only left/right with
CHS12 bits4:3. The existing native codec reproduces that stereo algorithm.
The desktop speaker PCM instead exposes FL/FR/RL/RR. A single stereo selector
cannot express the four required corner permutations. The OEM source is
GPL-2.0-only; it is inspected unchanged and no calibration values are imported.

The proposed kernel path changes only program-channel order in the admitted
speaker MFC before the protected RX module. Fixed physical amplifiers, DSP
protection/calibration, VI source, TDM transport and microphone graph retain
their original identities. The canonical input/output order is TL,TR,BL,BR,
corresponding to existing FL,FR,RL,RR. Transform90 uses source indices1,3,0,2;
180 uses3,2,1,0;270 uses2,0,3,1. Native0 is the existing reference.

The machine ALSA control uses the backend DAI channel-map callbacks. The LPASS
layer admits only the exact Uke secondary TDM route and the existing protected
graph with one MFC instance0x442e. It uses the existing AudioReach output-media
format API, standard channel identities and current48kHz/16-bit backend format.
Idle changes only cache the request. Prepare restores the mapping before START.
Graph open/prepare/start/close and live changes share one mutex. A failed change
reapplies the saved map; failed rollback invokes existing amplifier fault
containment. Legacy per-amplifier controls remain, but the aggregate operation
keeps them canonical to avoid applying a second stereo transformation.

Linux7.3.3 commitd50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd supplies the
compared `q6apm-lpass-dais.c`, `q6apm.h`, `audioreach.h` and `audioreach.c`.
Existing MFC `PARAM_ID_MFC_OUTPUT_MEDIA_FORMAT` accepts an ordered channel map.
This API evidence is not proof of live firmware acceptance or physical order.
No matching same-SoC four-corner native implementation was established in the
pinned donor inventory; other-board slot and amplifier maps are not used.

KWin6.8.2 commitf130ab33c8e6f3b9d728aade87836086ae9a8ed4,
`src/wayland/output_interface.cpp`, preserves native mode size and emits output
transform separately. The original compositor remains unchanged; session policy
and rotation lock stay in the existing Control notifier. Closed-cover/external
display and DPMS require separate acceptance, with no raw-accelerometer override.

The full recipe requires a terminal successful quad receipt for the exact
source commit and version, bound by an independently admitted digest. It refuses
an older non-quad entry at the same commit. Prepared fixture and recipe flags
are not claims that their tests or hardware acceptance passed.

Required next steps: native actual-function and lifecycle tests, real AArch64
card/LPASS objects and module linkage; source/feature/rollback admission; single
cumulative COPR/DNF delivery; four physical KDE corner tests, live rotation,
idle reopen, suspend/resume, fault/restart and closed-cover/external behavior.
Gain remains223. No new RPM, service, software audio mixer or per-sample CPU
processing is introduced. Microphone remapping is a separate open task.


## Device rejection and coefficient candidate

Full8/11287899 boots with matching Image/modules/DT and settings, but ADSP
audio_process crashes and battery queries subsequently return EPIPE. The operator
reports display/USB instability, long freezes and reboots. Full8 is rejected.
Source45 fixtures and ARM64 objects did not prove live firmware safety. Running7
is restored while the replacement is qualified; gain remains223.

The new candidate removes the second OUTPUT_MEDIA_FORMAT command after prepare.
Canonical rotation0 emits exactly the original prepare command stream. Other
rotations use PARAM_ID_CHMIXER_COEFF(0x0800101f), one56-byte table: fixed FL/FR/LS/RS
input and output identities with a4x4 Q14 permutation. Each row and column has
one unity coefficient(16384), no mixing gain or physical protection remapping.
Live changes use this coefficient API, not format renegotiation. Snapshot,
rollback, fault containment and the graph-lifetime mutex remain.

AudioReach engine5773bf8e627c9857481dd338a9ec4aea4a49afd3, BSD-3-Clause,
modules/cmn/pcm_mf_cnv/capi/mfc/api/mfc_api.h explicitly includes this parameter;
modules/processing/channel_mixer/api/chmixer_common_api.h specifies the table
layout, canonical maps and unit-gain coefficient bounds. The unchanged source
is retained as reference. Uke binary module support and physical playback still
require measurement. The extra format command is a source-level regression
candidate, not a proven explanation for every USB/display or reboot symptom.

The added native fixture checks actual request bytes, fixed channel identities,
row/column unit gain, rejected short buffers, allocation errors and DSP failures.
The LPASS fixture additionally rejects an extra DSP command at canonical prepare.
Real ARM64 objects, complete source proof, full9 and device qualification remain
pending. Do not replay the rejected full8 to manufacture a reproduction.
