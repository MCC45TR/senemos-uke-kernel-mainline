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
