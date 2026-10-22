# Uke AudioReach source status, 22 October 2026

Environment: Linux 7.2.12; POCO Pad X1 running baseline 7.2.12-9, Fedora
Rawhide AArch64. No ALSA cards or PCMs were present in the passive check on
22 October. Internal speaker and microphone support remain unavailable.

Patch 0079, ported from project commit `693dfd4`, fixes four reviewed startup/input problems: a request sent before
APR installed the receive callback; stale readiness after request failure;
global provider publication before successful probe; and unchecked response
header/payload lengths. Readiness tokens and state are synchronized so an old
response cannot satisfy a later query. The accessor is serialized with removal.
This does not resolve every graph/DMA/PDR callback lifetime.

The 7.2.12-10 candidate selects `services-only` in
`packaging/native/audio-profile`. This adds
native APM and PRM service ports 1/2; OEM clients 3/7 remain separate. Both DAI
children remain disabled. The required DAI IOMMU descriptions use the exact
OEM context banks and do not enable DMA. No sound card or physical audio path
is created by this profile. Keep the amplifier I2C bus and SLIM disabled.

Patch 0099 carries the reviewed publication fix from project commit
`e4b196c060de5261c6469ac913622e6b99fc0496`. It initializes device references
before naming, unwinds failed naming/DT/IDR allocation, and removes the router
entry under its callback/IDR locks if `device_add` fails. The prior source
leaves a pointer to a released service after failed registration. The fault
fixture covers both APR and GPR, optional/malformed protection-domain data,
allocation/name/IDR failures and an occupied service ID. Full transport/PDR
and remote DMA teardown remain separate work.

Protocol evidence: MiCode audio
`8eb0eccbc4027ae4a4987e4bced03a4381039714`, `dsp/spf-core.c`,
`dsp/audio_prm.c` and `include/dsp/audio_prm.h`. The same module IDs appear in
Peridot `2ed9eadbecae21ef51134e556951e7305ba65f88` `palawan.dtsi`.
No Peridot amplifier settings, channel map, GPIOs or calibration were copied.
Linux changes retain their existing GPL notices.

Host fixtures extract the actual changed functions. They cover truncated and
optional GPR headers, PRM payload bounds, readiness timeouts and stale tokens,
failed/duplicate probe, provider removal, and disabled physical paths in the
generated FDT. AArch64 translation-unit compilation is separate from device
operation. New tests run in the RPM check phase; compiler-rt is host-only.

`src/audio/fs19xx-preset-audit.cpp` is a host-only C++ file-format inspector.
It validates the outer preset size/checksum, device indexes, selected address
set, known family types, nested index bounds and speaker-info position masks.
It never outputs register/tuning data, loads a kernel component or writes
calibration. A structural pass is not electrical compatibility or permission to
unmute. Other nested payload semantics and protection remain unqualified.

The stock Global OS3.0.304.0 `libfsalgocal.so` identifies the consumer of
`fsalgo_rdc.bin`. Static AArch64 inspection of `fsm_algo_set_re25` reads four
32-bit Q12 resistance values into four zero-initialized 24-byte records and
sends 96 bytes using parameter 0x10001fa7. This differs from the versioned
packed `fsadsp_cmd_re25` in MiCode `fsm_q6afe.h`. Neither the stock missing-file
fallback nor the old packed layout is admitted for a native speaker path.
The file has no embedded channel identities or integrity header; byte count
alone cannot qualify calibration or establish amplifier order. The library
was inspected as data and was not executed or added to a target payload.

The exact stock ODM overlay includes four distinct single-microphone routes:
top AMIC3/ADC3, sidetop AMIC5/ADC2, sidebottom AMIC1/ADC1 and back AMIC4/ADC4.
Other multi-mic paths use different ADC assignments. These are route-specific
source observations, not a tested four-channel capture map.

Remaining work: native APM/PRM binding and firmware handshake on the tablet;
WCD939x/LPASS supplier and wakeup conversion; capture graph and physical mic
mapping; native amplifier component/protection; calibration validation and
channel binding; UCM and physical acceptance. Service registration creates no
sound card and must not be advertised as working internal audio.
