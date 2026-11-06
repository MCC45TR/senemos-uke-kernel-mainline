# Static APM configuration intents

6 November2026, POCO Pad X1, native7.3.1-12210-unstable. The protected backend
704-byte OPEN succeeds after the route correction. A bounded zero-PCM test
passively records a5416-byte SET_CFG failure at both gpr_send_pkt and
qcom_glink_trysend. Smaller OPEN/SET_CFG/disable/CLOSE packets succeed.
The protection state faults, erases its staged data and keeps outputs muted.
Header-only probes never read or publish calibration/parameter payloads.

APR sends under a service spinlock through rpmsg_trysend. GLINK cannot request
a missing sufficiently large remote intent in that path. Add a separate
process-context static-service API using rpmsg_send. Hold the existing callback
mutex across validation and sending, matching static-service quiesce/removal.
Read the service map under its spinlock, release it before the sleepable call,
and reject a removed or quiesced service. The caller retains device/packet
ownership and stays outside GPR callbacks. GLINK intent grants are independent
of the packet router's queued GPR callback dispatch.

Only synchronous APM SET_CFG uses this API. Dynamic ports, asynchronous sends,
readiness commands, legacy APR, packet domains, headers, protected tuning,
private calibration and gain223 retain their contracts. Do not truncate a
parameter record or replace the kernel fault gate. Transport-level GLINK
fragmentation remains its existing implementation.

The native fixture executes actual prepared APR, AudioReach and GLINK send
functions with a fake remote intent. It reproduces the original5416-byte
EBUSY, verifies complete byte preservation, negotiation/fragmentation, peer
refusal, timeout/cancel/transport errors, service removal/quiesce and unchanged
nonblocking paths. It runs with GCC/Clang and sanitizers in COPR. The inherited
unmap fixture gains only two mock declarations for the added API; all existing
assertions remain. Actual APR/AudioReach AArch64 objects and every cumulative
gate are required before a full candidate.

Initial check16/11269595 stops during preparation because the unchanged GLINK
fragment triggers sign-compare under the fixture's extra warnings. Linux7.3.1
scripts/Makefile.warn disables it at the default warning level. Apply that
same policy only around the imported
GLINK fragment; keep all other fixture/new-code warnings and -Werror. The
production patch is unchanged; fresh check17 performs the qualification.

References, unchanged: Linux7.3.1 drivers/soc/qcom/apr.c,
drivers/rpmsg/qcom_glink_native.c and sound/soc/qcom/qdsp6/audioreach.c;
current upstreamf66469d9905b39d2c260a15d7d6db450f4db67c1 and remoteproc
for-nextf247008989dfb887318be1db39792d262e2506e8 retain nonblocking APR sends.
Exact Uke OEM5712080a4b0c0b1a879e6d145c601c649ddaddfd and OnePlus SM7675
fc892483f1d61f245924681eb5abd563564d9cba GLINK share the intent contract.
Uke audio8eb0eccbc4027ae4a4987e4bced03a4381039714 ipc/gpr-lite.c
(blobe0ca37157d97650354d2d0ea57cc98a5f76e407c) also uses trysend; its
Android lifetime/dispatch interfaces are not transplanted. Linux APR/GLINK
are GPL-2.0-only with Qualcomm/Sony/Linux Foundation notices; AudioReach is
GPL-2.0 with Linaro attribution. The pinned donor inventory and policy apply.

Source/native results do not establish fitted intent allocation, DSP parameter
acceptance, actual limiting, sound quality, physical speaker safety or complete
transport/PDR recovery. A signed cumulative COPR/DNF kernel and physical tests
remain required. No local driver binary or parameter substitution is installed.

Full12211/COPR11269695 subsequently passes1759seconds of native checks and827
module signatures, is DNF installed and boots in B with A12210 retained.
Actual5416-byte negotiation receives grant1 but no new adsp_apps intent before
ETIMEDOUT. Smaller configuration/disable/CLOSE succeeds, with Fault and all4
outputs muted. Sleepable negotiation alone does not qualify this record. The
following shared-memory work preserves this API and every cumulative gate;
see [Protected APM configuration](PROTECTED-OOB-CONFIG.md).
