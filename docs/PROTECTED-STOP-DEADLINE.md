# Muted STOP deadline

7 November 2026, POCO Pad X1, 7.3.3-1-unstable. A complete passive trace records
all four mute/readback callbacks finishing at574.109269 seconds. The worker
exhausts its200 startup polls and faults at577.396064 seconds; the DSP STOP
timeout follows at579.296390 seconds. Three preceding START calls succeed.
The6076 recorded events have3038 paired calls and no buffer overruns or
unmatched records. Useful playback is not accepted: the attempted stream
exits1 and four active links are not observed. No further PCM or reset follows.

Opcode0x01001003 is STOP. Earlier first-boot notes that call it START are
superseded. The earlier startup trace overwrote938 CPU0 events and cannot be
used as a complete causal comparison. Timer and callback evidence does not
establish acoustic protection, microphone quality or audible output.

The codec currently reuses its two-second startup PLL poll budget while a
read-back-muted DSP STOP can wait five seconds. The candidate gives this muted
phase a separate absolute six-second fallback. A pending worker sees the
already armed deadline rather than consuming startup polls. No worker may
unmute during that phase. Normal completion cancels it; a fault or elapsed
deadline still resets hardware and publishes Fault. Restart during drain is
refused. Running-output health, gain223, calibration and DSP configuration stay.

This repairs a demonstrated lifetime mismatch. It does not prove why the DSP
has not acknowledged STOP earlier, or that every STOP failure shares one cause.
The sequential mode1 notification boundary also needs explicit interleaving
review before full integration. No full kernel or public full revision is
reserved by the focused callback proof.

## Sources and limits

The pinned donor inventory and workspace donor policy apply. References remain
unchanged; donor scripts and binaries are not executed.

- Exact Uke MiCode audio8eb0eccbc4027ae4a4987e4bced03a4381039714,
  `asoc/codecs/fs19xx/{fs1958,fsm_core,fsm_codec,fsm_q6afe}.c` and
  `fsm_q6afe.h`: Fourier notices, no per-file SPDX grant. The module entrypoint
  declares GPL; this does not establish an exact license version for every
  file. Shutdown distinguishes DAC mute and amplifier power removal. No donor
  implementation, tuning or private calibration is copied.
- Same-SoC OnePlus1138e00fee63582a0cc6a53af3286621786827b7,
  `vendor/qcom/opensource/audio-kernel/asoc/msm_common.c`, GPL-2.0-only,
  Linux Foundation/Qualcomm: lifecycle comparison without this native guard.
- Signed Linux7.3.3/d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd,
  `sound/soc/qcom/qdsp6/{q6apm,audioreach}.c`, GPL-2.0/Linaro: the synchronous
  APM wait is5*HZ. Current upstream q6apm path commit
  a51c5dd7f7fc7cdf4ae28fec4a013d8418d1cb53 concerns buffer removal and does not
  supply this deadline correction.
- The23October WSA884x protection RFC and28October review remain applicable
  comparisons for live VI ownership. They use a different amplifier transport.
  The8October failed-STOP caller RFC concerns subsequent prepare refusal.
  Neither establishes the cause or acceptance of this Uke-specific failure.

New project code is GPL-2.0-only. Focused COPR checks execute the actual codec
worker, mute helper, gate and STOP callbacks with independent I2C/DSP/timer
providers, two compilers, sanitizers and100/250/1000Hz timers. The exact original
worker must fail a five-second muted drain; unbounded, premature and lost-fault
mutants must fail. Complete source inverse comparison remains required.
Actual cumulative kernel objects, linked modules, all historical gates and
physical repeated-speaker operation remain separate, mandatory admission.
