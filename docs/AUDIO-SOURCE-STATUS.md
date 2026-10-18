# Uke AudioReach source candidate, 18 October 2026

Environment: Linux 7.2.11; POCO Pad X1 baseline kernel 7.2.11-2. Internal
speaker and microphone support remain unavailable. This source candidate is not
installed hardware acceptance.

Patch 0079, ported from project commit `693dfd4`, fixes four reviewed startup/input problems: a request sent before
APR installed the receive callback; stale readiness after request failure;
global provider publication before successful probe; and unchecked response
header/payload lengths. Readiness tokens and state are synchronized so an old
response cannot satisfy a later query. The accessor is serialized with removal.
This does not resolve every graph/DMA/PDR callback lifetime.

`packaging/native/audio-profile` defaults to `disabled`. `services-only` adds
native APM and PRM service ports 1/2; OEM clients 3/7 remain separate. Both DAI
children remain disabled. The required DAI IOMMU descriptions use the exact
OEM context banks and do not enable DMA. No sound card or physical audio path
is created by this profile. Keep the amplifier I2C bus and SLIM disabled.

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

Remaining work: WCD939x/LPASS supplier and wakeup conversion, capture graph and
physical mic mapping, native amplifier component/protection, calibration
consumer/schema, complete stream/SSR/PDR cleanup, UCM and physical acceptance.
The default-disabled source profile must not be advertised as working audio.
