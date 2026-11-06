# Protected APM configuration in shared memory

6 November 2026, POCO Pad X1, complete7.3.1-12211-unstable. Protected graph
OPEN succeeds. A5416-byte SET_CFG now requests a GLINK intent and receives
grant1, but no matching receive buffer is advertised before timeout. Smaller
commands, including protected disable and graph close, succeed. Fault, erasure,
gain223 and four muted amplifier outputs remain. This is not sound acceptance.

AudioReach graphservices558ddfc2c87019496957855c209dd5ece4f6aceb,
`gsl/src/gsl_graph.c`, sends custom configuration larger than256bytes through
shared memory. `spf/api/apm/apm_api.h` defines the address/handle/size command
header and per-module error in the shared TLV. `apm_memmap_api.h` defines the
mapping contract. These Qualcomm files are BSD-3-Clause. The open queue was
reviewed at the same head; no queued change replaces this transport contract.

Exact Uke audio8eb0eccbc4027ae4a4987e4bced03a4381039714,
`asoc/codecs/fs19xx/fsm_q6afe.c` and `.h`, also selects shared memory at256bytes.
Its2016-2020 Fourier implementation is evidence of an older AFE interface,
not an active Uke solution: `fsm-dev.h` leaves CONFIG_FSM_Q6AFE disabled and
Kbuild selects only fsm_core/fs1958/fsm_i2c. Its fixed4K allocation cannot be
copied for a5360-byte record. No donor implementation is transplanted.

The new core builds one complete5376-byte module TLV in a dedicated8192-byte
allocation and uses small MAP/SET_CFG/UNMAP commands. It verifies page/32-byte
alignment,36-bit bounds, the original protected instance/parameter/size,
per-module status and unchanged parameter bytes. It never splits a record.

Unsent mapping commands may release their local allocation. Once a map might
have reached the peer, a missing handle or ambiguous response retains erased
pages and callback state. A timed-out module command cannot be made safe merely
by receiving an unmap ACK: it might still be reading. Such a client remains
quarantined. Normal release follows an explicit completed configuration and
successful unmap. The integration must keep all outputs muted on failure.

`tests/audio-fs19xx-oob.c` supplies an independent fake APM peer, checks exact
wire formats/full bytes and remote ownership across18 success/fault modes,
and rejects unsafe-free, missing-module-error and alignment mutants. GCC/Clang,
sanitizers and an actual AArch64 header bridge run only in COPR. The bridge is
neither a driver nor a hardware result.

Initial check18/11270018 passes all4 OOB modes and8 assertion mutants, then
fails the inherited historical configuration digest before kernel objects build.
The native repository moved Clang/LLVM23.1.4 to23.1.5. The next check pins the latter
three RPMs and retains the original sealed guard. Its separate historical model
projects only four explicitly validated compiler identities to23.1.4; every
functional option remains in the same original digest. Actual configurations
and compiler provenance stay unchanged. The real normalized23.1.5 output must
pass that guard, reproduce the original refusal and reject five malformed/
functional controls before native objects can qualify. A nonidentity change
still refuses the build. The OOB core's bytes are unchanged.

Check19/11270202 stopped before SRPM creation: the inherited spec contains the
same configuration check in both build and install, while the transformation
required one match. Check20 requires both matches and retains both checks.
The compiler identity projection and native header bridge remain unqualified.

The kernel DMA/response-port backend is not yet admitted or activated. It must
prove the exact Uke physical/SID address interpretation, device and response
lifetimes, strict source/token/opcode/length matching, cache barriers and
bounded quarantine across timeout/removal before replacing the current sender.
The existing FE uses fitted SIDs0x1001/0x1061; borrowing its PCM allocation or
assuming another device's DMA context is not an acceptable shortcut. No new
DT resource, live DMA, calibration access or amplifier operation occurs here.

The23October2026 WSA884x speaker-protection RFC, patch14/23, sends static
configuration in512-byte groups at parameter boundaries; a larger individual
parameter is still sent whole. It therefore does not replace this transport
for the fitted5360-byte FourSemi record. Its WSA884x modules and calibration
are not Uke FourSemi evidence. See the
[author's patch](https://lkml.iu.edu/hypermail/linux/kernel/2610.2/19117.html).

References: Linux7.3.1 `sound/soc/qcom/qdsp6/{audioreach,q6apm,q6apm-dai}.c`
and `audioreach.h` (GPL-2.0, Linaro); current upstream
f66469d9905b39d2c260a15d7d6db450f4db67c1; exact Uke OEM and pinned SM7675
donor policy. Source/core/native compilation and physical DSP acceptance remain
separate. Preserve complete12211 and every cumulative protection/feature gate.
