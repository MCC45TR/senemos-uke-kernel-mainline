# Speaker volume ceiling investigation

3 November 2026. POCO Pad X1 / Xiaomi Pad 7. Read-only source/control inspection;
no gain change, tone generation, calibration run or new playback test.

The native FS19xx driver deliberately caps the digital register at 223 (`0xdf`).
Both direct mixer writes and preset writes are bounded by that ceiling. The
running tablet reports maximum 223 and current value 223 for all four amplifier
controls. Raising the desktop slider cannot raise this hardware ceiling.

The exact stock Uke
[mixer overlay](https://github.com/delano-git/android_vendor_xiaomi_uke/blob/87f59fc5c2ef1ee04e494e5258853d36a3346059/proprietary/odm/etc/audio/sku_cliffs/mixer_paths_overlay_static.xml)
selects 243 for ordinary speaker playback and 235 for several individual-speaker
scenes. Its initial 255 setting is overridden by the selected playback route;
255 is not evidence for a normal full-volume target. The native/normal-stock
gap is 20 register steps. An exact acoustic dB, loudness or power ratio cannot
be inferred from those steps without a validated FS19xx scale and measurement.
Earlier estimates of a 7.5 dB difference are not qualified measurements.

The MiCode
[volume writer](https://github.com/MiCode/vendor_qcom_opensource_audio-kernel/blob/8eb0eccbc4027ae4a4987e4bced03a4381039714/asoc/codecs/fs19xx/fsm_core.c)
contains a commented-out calibrated/uncalibrated `0xdf` selection. The active
path writes `cfg->volume`. Therefore the current native ceiling is a local
conservative policy, not a verified universal OEM rule for uncalibrated devices.
The protected candidate corrects that misleading source comment while keeping
the numerical ceiling unchanged.

The inspected UCM speaker PCM performs conversion to S16_LE / 48 kHz / four
channels and contains no extra fixed gain reduction. Stock FourSemi processing,
SAL limiting and Android effects also differ from the existing raw native path;
the ceiling alone does not explain all perceived quality/loudness differences.
A desktop volume below unity can reduce playback further, but its setting is
session state and has not been established as the reported problem's cause.

The next safe volume change requires a physically qualified VI/DSP chain,
validated per-channel feedback, clipping/THD measurements and temperature/power
limits. The runtime and kernel candidate do not authorize 243 or 255. No gain
increase is included in this work.

## Safety hardening before any higher-gain admission

The follow-up candidate keeps 223 as its ceiling. No module parameter, DT
property, mixer switch or successful calibration transaction authorizes 243.
The final register writer now independently rejects values above 223, including
calls that bypass the mixer-facing validation.
If a live mixer gain write fails, the candidate immediately stops/resets the
output and latches the protected group fault instead of waiting for a poll.

The exact Uke codec had enabled/read back its temperature-sensing bit after
writing DAC RUN and performed no later output-health check. The candidate now
holds DAC mute while enabling sensing, then verifies sensing readback, PLL,
power controls, the complete ten-bit gain field and the shared DSP guard before
DAC RUN. The same checks run during playback. A failed read or changed state
stops/resets the amplifier; the protected profile also latches a group fault.
Healthy polling never rewrites DAC RUN or repairs a lost sensing bit in place.

The 250 ms poll is a diagnostic interval, not an established thermal, overcurrent
or excursion response deadline. TSEN is a sensing-enable bit, not a measured
voice-coil temperature or a verified limiting threshold. The Uke OEM source
names other status bits without a usable active monitoring implementation for
this variant; their polarity, latch/reset semantics and safe limits are not
invented. Upstream FS210x has a different device/register contract and cannot
supply FS19xx fault masks or protection limits.

The group guard now observes mode and fault state under one spinlock. A fault
changes its generation; a provisioning transaction cannot clear a fault newer
than its BEGIN ticket. Pending group-mute work is drained before successful
reprovisioning, and a fault arriving during arming defeats that transition.
Amplifier removal latches a fault as well. No automatic retry clears it.

The conditions for admitting a higher ceiling remain:

| Condition | Current evidence | Remaining evidence |
| --- | --- | --- |
| Four per-unit calibration records and identities | Read-only reader/schema fixtures; no defaults or exports | Electrical validity and exact physical channel binding on the protected runtime |
| Matched DSP/firmware and protection parameters | Pinned generic data, RX/TX/IMCL source and object compilation | Complete matched kernel/package, actual DSP acceptance and stock limiting/effect-chain equivalence |
| Real VI feedback | Stock four-channel format and channel types identified | Per-channel mapping, scaling, freshness and continuity measured at low output |
| Local amplifier containment | Pre-unmute and ongoing status/gain checks with fault-injection fixtures | Bounded physical response, suspend/reset/removal and repeated-playback acceptance |
| Thermal, electrical and mechanical limits | No qualified safe-higher-gain conclusion | Verified Uke transducer limits and non-damaging tests of power, clipping, temperature and excursion containment |

The existing speaker-info fields include nominal-resistance/temperature-related
metadata. Those names alone do not establish a valid Re25 acceptance range, VI
conversion, real-time coil-temperature observation or a complete protection
model. No new numeric limits are derived from names or another amplifier.

Physical fault checks should begin with outputs muted, then use bounded low-level
playback after the matched candidate passes packaging. Do not induce real
overcurrent/overheating or use full-volume playback to discover safe limits.
Only after the remaining evidence supports the complete protection path can a
separate change admit 243. Software fixture success alone does not do so.

COPR [11251430](https://copr.fedorainfracloud.org/coprs/build/11251430), source
`adad562`, passes GCC/Clang sanitizer fixtures against the extracted actual
codec functions and the generation guard. It also compiles all six affected
kernel translation units and the protected topology. The receipt RPM installs
no kernel, driver or topology. The later live-write failure correction receives
its final passing check in
[11251473](https://copr.fedorainfracloud.org/coprs/build/11251473), source
`15b7626`, receipt `uke-speaker-kernel-check-0.1-3`. Both GCC/Clang sanitizer
fixtures include the actual mixer callback, negative/high requests, valid gain
changes and immediate stop after a failed live write. All six affected kernel
objects and the protected topology compile again. No tablet activation or
higher-gain acceptance follows from either source check.
