# Speaker enable control integration

7 November 2026. Candidate source only; native qualification and target query
results are pending. Keep the running7.3.3-3-unstable and its gain223 ceiling.

This extends the [query draft](SPEAKER-ENABLE-READBACK.md) with one ASoC
control, `FS19xx DSP Enable State`, inside the existing APM module. It reads
two fixed four-byte enable parameters. No daemon, runtime package, DSP mode
writer, mapped DMA, arbitrary parameter or calibration GET is added.

Unprivileged reads and inactive, absent, removing or unadmitted graphs return
Unavailable without contacting the DSP. A privileged read holds the existing
owner mutex, checks the running guard, executes two bounded queries, then
rechecks the guard and its fault generation. A revoked or changed generation
cannot publish a result. The original provisioning, state getter, graph and
codec callback implementations remain byte-identical through an exact inverse
patch. Only one include and one control-array entry are added to runtime.c.

States are Unavailable, Both disabled, RX only, TX only, RX and TX enabled,
and Query failed. Disabled is a valid observation, not an unsupported response.
Query errors never reset, reprovision or mute a healthy speaker stream.
Each wait is bounded to250ms; these timings are diagnostic, not a safety lease.

Integration review found a mismatch in the earlier focused query draft:
it rejected the complete16-bit field named reserved by Linux. The already
qualified Uke GPR contract accepts its low client byte and rejects the upper
reserved byte. The original query84-case test covered only zero client data.
The parser now accepts every low-byte value, including fitted0xc8, while
retaining refusal of each upper-byte bit. The backend fixture also returns0xc8.
This uses the existing pinned graphservices558ddfc2 `gpr/api/gpr_packet.h`
contract and Uke client-byte qualification11272542; no new relaxed packet
identity, opcode, token, length, module or status rule is introduced.

The cumulative recipe retains the qualified PCM workqueue, all previous
hardware/config/DT/firmware gates and both panel suppliers. Old checkers use
an authenticated parent source view only after verifying the complete new
runtime hash and exact inverse delta. New source/backend/ASoC objects and the
APM composite are separately checked. Extra debug RPMs remain disabled.
The offline-charging draft stays deferred and is not activated by this layer.

Compiler/sanitizer tests cover the production packet parser/backend and the
actual control initializer/getter, with independent synthetic transport and
guard changes. Actual cumulative AArch64 object/composite validation precedes
a full candidate. On-device acceptance must then read the fixed modules during
bounded low-output playback, retain four outputs and successful STOP/Ready,
and establish honest unavailable behavior after teardown.

Enabled RX/TX bits are not the proprietary limiter mode, VI samples or proof
of safe243. The separate calibration/output binding, gain conversion, VI
scale/continuity and physical limiting/containment evidence remain required.

## Initial cumulative check correction

COPR11284463/source17 fails279s after all four new347/23/617-case modes and
24 required mutants pass. The old state-store fixture extracts the actual
control table but did not import its new descriptor macro. It fails compilation
before the new kernel objects; no native-object qualification is claimed.
The compatibility patch imports the real macro, keeps every original replay
assertion and additionally verifies the third control is read-only/volatile,
has no put callback and leaves provisioning READY on store. Its exact original
and revised sources are sealed. Production C/headers, query and gain stay
unchanged. Published proof17 is not reused; source18 is history-derived while
the unreserved full candidate remains4.
