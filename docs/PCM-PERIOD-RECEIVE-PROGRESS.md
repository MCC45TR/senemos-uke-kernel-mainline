# PCM period delivery and ordered GPR progress

7 November 2026, POCO Pad X1, cumulative 7.3.3-2-unstable. Four internal
speakers were audible before a test, as reported by the user. A subsequent
same-kernel boot fails naturally without an agent PCM request: APM STOP
0x01001003 waits 5196.609 ms and returns -ETIMEDOUT. The complete passive
capture has 4862 events, 2336 matched call pairs, 190 basic responses, no
unmatched calls, overruns or drops, and 53 uniquely matched probe counters
with zero missed hits. No APM response is observed inside the failed wait.
Responses after it carry token zero and cannot be attributed uniquely to that
failed command rather than subsequent cleanup. Do not call them proven late ACKs.

The candidate addresses a source-level lock cycle. GPR uses an ordered receive
worker. The PCM callback calls snd_pcm_period_elapsed directly; nonatomic PCM
notification can wait for a stream mutex held across synchronous DPCM STOP.
That wait can block following APM completion on the same receive worker. This
is a hypothesis for the measured failure, not a physically proven root cause.

PCM notifications are queued on system_unbound_wq. Repeated pending periods
coalesce and ALSA reads the current hardware position. Capture resubmission,
EOS, compressed callbacks, formats, DMA and all protected amplifier controls
remain. PCM close and failed open close the enqueue gate and drain pending or
running work before graph/private-data release. The valid graph opened before
a later constraint failure is also closed; failed graph-open quarantine stays.
Cancellation runs outside the enqueue spinlock and after core stream locking.

COPR tests extract the actual event and work helpers with independent pthread
providers. They hold the PCM mutex and require a following ordered APM event
to progress; exercise pending/running close, concurrent enqueue/close, capture,
EOS and bounded coalescing. Exact original event code and three unsafe mutants
must fail. GCC, Clang, ASan and UBSan are separate modes. Whole-file preimage,
postimage and inverse comparison, unchanged code paths and actual AArch64 PCM
objects are additional gates. No tests compile or request audio on the tablet.
Build evidence cannot establish audible output, repeated STOP reliability or
amplifier safety. Gain remains 223; protected gain 243 is not admitted.

## Source comparison

References remain unchanged under the owner's reference archive. No tuning,
calibration, board values or donor implementations are copied.

- Signed Linux 7.3.3, d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd:
  sound/soc/qcom/qdsp6/q6apm-dai.c (GPL-2.0, Linaro 2021),
  drivers/soc/qcom/apr.c (GPL-2.0), and sound/core/pcm_native.c (GPL-2.0-or-later).
  Inspect GPR receive ordering, nonatomic stream locking and release ordering.
  The ALSA driver API documents period batching and stream-lock ownership:
  https://kernel.org/doc/html/next/sound/kernel-api/alsa-driver-api.html
- Upstream q6apm-dai history through 0ea3e0b196f9dcc17b40ac881a6efef06459975b
  covers position wrap; bb8afd437d79161592663142a67179565dce4f41 and
  9c9fb79f9769ba9042086817ee57aa4eef8b8a97 cover SCM buffer assignment and
  zero initialization. No applicable deferred-period fix was found in this
  bounded history; this is not a claim about all outstanding mailing-list work.
- Uke MiCode vendor_qcom_opensource_audio-kernel,
  8eb0eccbc4027ae4a4987e4bced03a4381039714: inspected asoc and dsp listings;
  asoc/platform_init.c is a GPLv2 empty platform entrypoint. The guessed legacy
  PCM file path is absent. This does not establish absence in every OEM repo.
- Same-SoC OnePlus modules, 1138e00fee63582a0cc6a53af3286621786827b7:
  inspected vendor/qcom/opensource/audio-kernel/asoc and dsp listings;
  asoc/msm_common.c (GPL-2.0-only, Linux Foundation/Qualcomm) is machine glue,
  not this native AudioReach callback. No matching implementation is assumed.

New project code is GPL-2.0-only. Original PipeWire/WirePlumber and desktop
packages need no change for this kernel candidate. Their runtime replacement
still requires independently verified DNF dependency closure and feature parity.
