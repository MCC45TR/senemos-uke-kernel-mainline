# Protected speaker STOP ordering

7 November 2026. Complete12216 boots in B on POCO Pad X1. HiFi exposes Speaker,
HDMI1 and the four-channel microphone array. Audible HDMI/DisplayPort is confirmed
on the device. Three protected configuration transactions successfully MAP,
SET and UNMAP dedicated RAM, with all validated SET/UNMAP status values zero.
The first later fault is a timeout of `APM_CMD_GRAPH_STOP` (0x01001003), followed
by protected Fault and refusal of subsequent speaker preparations. No manual
speaker retry, parameter reload, module reset or protection bypass is performed.
Four requested-on ALSA speaker switches do not establish physical DAC state.

The existing protected stop callback calls `stopped(false)` before sending DSP
STOP. Its gate-zero notification powers down and resets all amplifiers, also
removing their V/I transport. This layer tests the hypothesis that removing
feedback before the DSP has drained STOP causes the timeout. Source and peer
tests cannot prove that this is the only remaining hardware fault.

## Muted transport during STOP

Before DSP STOP, the runtime enters the existing configured, non-running guard
mode and notifies every amplifier. A new codec helper sets only the existing
DAC mute bit and requires stable readback. PLL, V/I, I2S, gain and temperature
configuration remain intact while STOP drains. The existing bounded guard wait
continues to stop hardware if completion stalls. No new indefinitely armed mode
or user control is added.

After the STOP response, the existing stopped callback powers off the amps.
Mute/readback/admission errors immediately power off and erase the private
cache; DSP errors also retain Fault and erasure. The original error is returned
even when cleanup also fails. Reference-counted partial stops and unrelated
graphs retain their old behavior. Gain223, all private tuning/calibration,
mapping lifetime, uncertainty rules and all cumulative features remain.

## Source comparison and attribution

The pinned inventory and shared donor policy were consulted. Earlier local
donor checkout paths are absent, so unchanged exact remote files were reviewed.

- MiCode/vendor_qcom_opensource_audio-kernel,
  8eb0eccbc4027ae4a4987e4bced03a4381039714,
  `asoc/codecs/fs19xx/fs1958.c`, `fsm_core.c`, `fsm_codec.c` and `Kbuild`,
  Fourier Semiconductor copyright notices. These files and Kbuild lack an
  explicit file-level license. The selected module entrypoint `fsm_i2c.c`
  declares `MODULE_LICENSE("GPL")`; that does not establish a particular GPL
  version for every reference file. The fitted-family shutdown
  code distinguishes DAC mute from power and system shutdown. Kbuild lists
  fsm_core, fs1958 and fsm_i2c; a listed file alone is not evidence that every
  codec path is selected in the fitted OEM build. No OEM tuning or board values
  are transplanted. The native driver already owns the DAC mute-bit definition.
- OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm7675,
  1138e00fee63582a0cc6a53af3286621786827b7,
  `vendor/qcom/opensource/audio-kernel/asoc/msm_common.c`, GPL-2.0-only,
  Linux Foundation/Qualcomm attribution. This same-SoC common shutdown path does not implement
  the project-specific native FS19xx guard or establish its STOP ordering.
- Upstream Linux d48723711bae9b8cdc56719c448ba42fef28cbee,
  `sound/soc/qcom/qdsp6/q6apm.c`, GPL-2.0/Linaro, retains the ordinary DSP STOP
  operation without this private pre-STOP amplifier-reset hook. Earlier
  f66469d9905b39d2c260a15d7d6db450f4db67c1
  `sound/soc/qcom/qdsp6/audioreach.h` identifies the observed opcode as STOP.
- The23 October2026 WSA884x active-protection RFC,
  message20261023171433.820092-1-srinivas.kandagatla@oss.qualcomm.com, and its
  control-link patch7/23 were reviewed. They require live VI feedback and
  distinguish playback and VI paths, but use different amplifiers/transport
  and do not provide this Uke-specific correction. No directly applicable
  queued FS19xx muted-stop fix was established.

New project code remains GPL-2.0-only. References are unchanged and no donor
scripts, board settings or calibration values are executed or copied into the
implementation. The native baseline is reconstructed from the hash-admitted
full12216 source patches; actual cumulative preimages must match before the
new layer applies.

## Qualification and remaining device work

Proposed COPR check38 executes the actual codec mute/readback/event, runtime
gate/stopping/stopped and graph-stop callbacks with independent I2C and DSP
drain peers. Four compiler/sanitizer modes cover40 cases, including all20 mute
I2C operations failing, ignored writes, DSP timeout/error, owner/removal/state
refusal, partial references, unrelated graphs and the actual bounded worker
stopping muted transport after200 polls. The original pre-STOP reset
path must fail the same drain assertion. Missing mute notification, premature
poweroff, ignored readback and unbounded-drain mutants must fail with both compilers.

Exact pre/post hashes, whole-source inverse comparisons and twelve altered
source/contract refusals retain every historical source gate. Original16
checkers remain archived and their checks run on authenticated preimages after
the exact new delta is sealed. All452 inherited nonidentity composition fields
stay. Actual cumulative AArch64 runtime, caller, codec and APM composite must
compile and resolve the new internal call; a full build also requires linked
Image/module/signature checks. No compilation runs on the tablet.

Full12217 remains proposed until source admission. Protected four-speaker sound,
repeated start/stop, useful microphone quality, suspend and physical limiting
remain separate acceptance gates. A two-second microphone meter obtains distinct
signals from AUX0..AUX3 without saving raw audio; its exact-sample-count recorder
exits1 with empty stderr, so this is bounded signal evidence. Initial wrong
speaker-position remapping produced two artificial silent channels and is not
a microphone hardware finding. Preserve HDMI playback and all user preferences.

Initial check34/COPR11282599 authenticates all four exact16 preimages, including
the complete STOP function, then stops at the second STOP patch hunk before
new callback compilation. Check35 expresses that verified function delta in
one contextual hunk. Implementation and expected postimage bytes stay unchanged.
The OEM reference license note is also corrected to distinguish absent file
headers from the module GPL declaration; no donor implementation is imported.

Check35/COPR11282604 confirms the same exact preimages but GNU patch refuses
the single hunk anchored at line1, before callback compilation. Check36 gives
the hunk its actual cumulative source position956. A local git apply/reverse
check with the exact function after955 inert prefix lines preserves the
expected function postimage and surrounding bytes. GNU patch is unavailable
on the tablet; its acceptance and actual cumulative native tests remain COPR
gates. No compiler or new package is run or installed locally.

Check36/COPR11282611 still refuses the GNU hunk at956 before callback
compilation, despite the extracted complete preimage hash matching the exact
patch old text. Check37 uses git apply with exact context and whitespace errors
for this four-file delta and its reverse comparison. A local source-only model
checks all four postimages and whole-file inverse identities. Actual cumulative
pre/post seals, the complete original-source inverse comparisons, refusal
controls and native compilation remain mandatory; no source check is relaxed.

Check37/COPR11282635 passes actual cumulative application, all new pre/post
source seals and complete inverse comparison, then stops at a missing
cancel_delayed_work provider declaration in the new test fixture. Check38
models pending work, modification and cancellation with the actual codec mutex
held; STOP completion must leave no scheduled amplifier work. Production
source and postimages stay exact. No new callback execution or native object
success is claimed for check37.
