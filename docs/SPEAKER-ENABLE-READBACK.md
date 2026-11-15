# Fixed AudioReach speaker enable readback

7 November 2026. Source draft only. The shipping cumulative kernel is
7.3.3-3-unstable, sourcefa9d36d7, qualified full COPR11283960. Its ceiling223
and existing protection/provisioning remain unchanged.

The installed runtime0.4-3 reports eight deliberately unverified physical
evidence fields. Those fields are static admission metadata, not live DSP
measurements. READY confirms cached provisioning; neither READY nor RUNNING
establishes the proprietary limiter's active mode or electrical behavior.

The exact Uke OEM audio release8eb0eccbc4027ae4a4987e4bced03a4381039714,
`asoc/codecs/fs19xx/fsm_q6afe.{c,h}`, describes module-enable1 as all protection
enabled and5 as protection disabled. Its Kbuild does not activate this Q6AFE
implementation on Uke. That old command is therefore not added to AudioReach.
Its `fsm_afe_get_livedata` actually requests CALIB0x10001fab; it is not a safe
source of live voltage/current/temperature units. No calibration GET is added.
The file-level Fourier notice does not supply a clear redistribution license;
these files are read-only references, with no copied implementation.

AudioReach graphservices558ddfc2c87019496957855c209dd5ece4f6aceb supplies the
BSD-3-Clause wire contract in `spf/api/apm/apm_api.h` and the in-band caller in
`gsl/src/gsl_graph.c`. GET_CFG0x01001007 replies with0x02001000, an overall
status and a parameter TLV; an accepted event or successful basic ACK is not
the requested value. Four-byte data can be returned with or without final
8-byte alignment padding. The current upstream Linux7.3.3 APM does not expose
this general query. Engine master5773bf8e627c9857481dd338a9ec4aea4a49afd3 was
also inspected as a framework reference; it is not the fitted DSP firmware.

`src/audio/uke-fs19xx-readback.{c,h}` implements only the already-provisioned
RX0x4040/0x11111611 and TX0x49fd/0x11111601 four-byte enable queries. Callers
cannot select an arbitrary instance, parameter, payload or mapped address.
Identity, source/destination, token, framing, both statuses and boolean range
are checked. Missing, malformed and unsupported replies remain errors.
The dynamic port is drained before its client is freed; two monotonic tokens
are never reused during the module lifetime. There is no shared DMA memory.
Each query waits at most250ms, a diagnostic bound rather than a protection
deadline. Failure does not reset or reprovision a working speaker path.

This is not registered as an ALSA control or invoked by the shipping runtime.
The later integration must hold the admitted graph owner's lifetime/mutex,
preserve the cumulative GPR callback-drain fix0088, and qualify actual AArch64
objects and teardown interleavings. A module reload starts a new token domain;
these diagnostics must never become a cross-reload safety lease or enable243.

The focused COPR test compiles the production parser and backend using
independent synthetic GPR providers with GCC/Clang and ASan/UBSan. It checks
disabled results, unsupported modules, stale/out-of-order/duplicate responses,
timeouts, send and allocation failures, token exhaustion and late callback
drain. Six parser mutants must fail assertions. This test does not build a
full kernel object or prove that the fitted proprietary modules implement GET.
Only the existing migration-check family is used; no runtime RPM or daemon is
added. Native qualification and physical readback remain pending.

The separate high-gain acceptance still needs the matching limiter mode,
factory-to-output binding,0x29 gain conversion, correctly scaled continuous
VI and authoritative transducer limits with measured fault containment.
Enable readback narrows one observation gap; it cannot replace those results.
