# Protected audio: target client byte and initial readiness

6 November 2026. Full12215 boots on POCO Pad X1 with the permanent audio
supplier, translated DMA attachment and three ALSA PCMs. Useful microphone,
four protected speakers and DisplayPort sound remain unqualified. Bluetooth
playback is preserved during diagnosis. This layer extends complete12215;
it does not change topology, channel counts, UCM, tuning or firmware.

The initial protected claim runs approximately63ms before the private parameter
publisher reaches Ready. That refusal occurs before DSP OPEN and graph-ID
publication, with no configuration exchange. A single subsequent muted zero-PCM
test after Ready successfully maps dedicated configuration RAM. Its SET reply
contains client byte0xc8 and is rejected by the previous low-nibble mask. The
transaction becomes uncertain; its erased mapping and transport lease remain
retained, and all amplifiers stay muted. No further test or reprovision is
permitted before a real restart. A successful MAP does not establish SET success
or useful sound.

## Changes and retained boundaries

The admitted Uke protected backend accepts the complete low client byte in
Linux's 16-bit `reserved` member and rejects every bit in the explicit upper
reserved byte. Domain, port, token, header and packet bounds, version, opcode,
status and nonzero mapping-handle validation remain exact. The5360-byte private
tuning record, DMA/DT ownership, lifetime, erasure, uncertain-transaction
quarantine, protection and existing gain ceiling223 are unchanged. This is a
target compatibility correction, not a general change to the upstream GPR bus.

The protected claim also waits for initial Empty/Staging publication using one
2000ms deadline per APM instance. The mutex is released while waiting so the
existing privileged parameter writer can finish. Ready is rechecked under the
mutex; Fault, ownership and removal refuse. Control publication and shutdown
wake waiters. No wait occurs in a GPR callback, no uncertain transaction is
retried, and no private file parsing or calibration is moved into the kernel.
Existing parameter hash/generation checks and pre-DSP claim checks remain.

## Source comparison and attribution

The pinned donor survey, acquisition inventory and shared donor policy were
consulted. Their older local checkout paths are absent in this environment;
the following exact remote files were reviewed as unchanged references.

- MiCode/vendor_qcom_opensource_audio-kernel,
  8eb0eccbc4027ae4a4987e4bced03a4381039714,
  `include/ipc/gpr-lite.h` and `ipc/gpr-lite.c`, GPL-2.0-only, Linux Foundation,
  Linaro and Qualcomm copyright notices. The header declares an8-bit
  `client_data` followed by an8-bit `reserved`; its older mask still reserves
  the upper client nibble. The receiver does not enforce that nibble mask.
- OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm7675,
  1138e00fee63582a0cc6a53af3286621786827b7,
  `vendor/qcom/opensource/audio-kernel/include/ipc/gpr-lite.h` and
  `vendor/qcom/opensource/audio-kernel/ipc/gpr-lite.c`, GPL-2.0-only. This
  same-SoC comparison retains the same declared byte layout and receiver
  behavior. No board resources or amplifier data are transferred.
- AudioReach/audioreach-graphservices,
  558ddfc2c87019496957855c209dd5ece4f6aceb,
  `gpr/api/gpr_packet.h`, `gpr/api/gpr_api.h` and
  `gpr/core/src/gpr_drv_island.c`, BSD-3-Clause, Qualcomm attribution. The API
  arguments and packet declare8-bit client data. Allocation and reply paths
  copy that entire byte without nibble masking.
- Upstream Linux f66469d9905b39d2c260a15d7d6db450f4db67c1,
  `include/linux/soc/qcom/apr.h` and `drivers/soc/qcom/apr.c`, GPL-2.0.
  Linux names both bytes `reserved`; the common receiver does not impose this
  protected backend's additional nibble refusal. No applicable upstream queued
  fix for the project-specific backend or initial private publication was
  established.

[AudioReach's GPR design](https://audioreach.github.io/design/gpr_design.html)
explicitly documents four usable client bits and four reserved bits. The
observed fitted firmware differs from that documented restriction. The scoped
full-byte correction follows the declared byte field, allocation/reply copy
contract and measured0xc8 response; it does not claim that the design document
specifies eight usable bits. References remain unchanged; no donor code or
private payload is included. New project kernel code remains GPL-2.0-only.

## Qualification

COPR source check33 must execute the actual backend with actual kernel GPR
declarations and an independently encoded peer in GCC/Clang normal and
ASan/UBSan modes. All256 client values, all eight explicit reserved bits,
identity/status/bounds/lifetime and allocation faults remain covered. Original
nibble behavior and reserved-bit/low-nibble mutants must fail assertions.

The actual readiness helper and extracted control/shutdown callbacks run29
deterministic cases per compiler mode, including unlocked63ms publication,
fault/removal/ownership, one deadline, spurious wakes and time wrap. Missing
notification, held-mutex and rearmed-deadline mutants must fail. These synthetic
peers do not model DSP scheduling or establish hardware success. Existing
private provisioning/parser controls still run unchanged before this layer.

Exact pre/post hashes, inverse comparison and eleven altered source/contract
refusals preserve both historical and new source checks. All437 inherited
nonidentity composition fields stay. Actual cumulative AArch64 runtime,
backend, provider and APM objects must pass, including wait/wake imports. A
subsequent full build requires the same qualified source, linked Image and
all cumulative feature gates. Full12216 is only proposed until source admission.

Matching boot, normal KDE profiles, useful four-channel microphone samples,
safe protected speaker output and audible DP remain separate physical gates.
Inactive-slot staging stays automatic and local rollback preferences persist.
No stable promotion or health approval is granted. Cover initialization, gray
handover and USB resume remain open behind the urgent audio work.

Initial check31/COPR11272447 passes the normal GCC8712-case backend and29-case
readiness test, then the missing-notify mutant fails compilation because its
intentionally unused mock callback is treated as an error. Check32 marks only
that test callback as intentionally unused so assertion refusal is exercised.
The production kernel patch, helper and source-seal bytes are unchanged. No
full kernel was reserved or installed from the failed check.

Check32/COPR11272464 passes all four backend/readiness modes, six readiness
mutants and eleven source-seal refusals. It then stops in an inherited callback
fixture because that peer lacks the new waitqueue primitives. Check33 retains
the original fixture in history and adds a timeout-only primitive peer around
the actual readiness helper, preserving every admission assertion. The actual
failed-OPEN fixture also receives a notification counter for the new shutdown
callback. Successful publication and notification faults remain covered by the
dedicated29-case test. Production kernel and source-seal bytes stay unchanged;
actual AArch64 object compilation and full kernel delivery are still pending.
