# DPU and CDSP display offload feasibility

6 November 2026, POCO Pad X1 / SM7675, Fedora 46 AArch64,
`7.3.1-12211-unstable`. This is a source investigation and implementation
proposal. It contains no new display driver or enabled offload path.

## Result

The display DPU cannot acquire additional scanout engines by adding a CDSP
phandle. CDSP could prepare pixels before DPU scanout, provided that a compatible
DSP program implements the selected operation. Neither successful CDSP startup
nor a completed FastRPC listener call establishes that pixel-processing service.
There is no qualified such program or DPU integration in the inspected sources.

The initial 12211 observation finds both DSI and DP connectors connected,
enabled and DPMS On, with CDSP running. Its advertised `cvp-glink-apps-dsp`
RPMsg device exists and is unbound. This is a useful native CVP research lead,
not a completed image operation. The observation does not establish why desktop
frames are late.
No benchmark, framebuffer capture, modeset, service bind or firmware command
was run for this investigation.

A read-only KWin support-information query reports active OpenGL ES composition,
Mesa 26.2.6 / freedreno FD732, internal refresh 144000 mHz and external refresh
74997 mHz. These are compositor-reported settings, not presentation timing
measurements. They confirm that composition already uses the Adreno graphics
path; they do not identify which stage limits a reported workload.

## Source comparison

| Source | Exact revision and inspected files | Applicable result |
|---|---|---|
| Uke OEM display | MiCode display `44275c404a677d9d9e5230fedd1af2ef02fc7b9a`; `msm/sde/sde_plane.c`, `msm/Kbuild` and bounded whole-tree symbol search | SDE planes, scaling, blending and color processing; no CDSP/FastRPC/CVP/EVA reference in the searched C/header/build inputs. The C code is GPL v2 with Linux Foundation, Qualcomm Innovation Center and earlier upstream attribution. No code is copied. |
| Uke OEM display DT | MiCode display-DT `4a3e1c391130237c5e8c2b250d1c94f3e25b9b11`; `display/cliffs-sde-common.dtsi` | The project's maximum bandwidth and minimum IB figures already match this description. The file has no per-file license header; no DTS material is copied. Resource or QoS differences need their own comparison before a change. |
| Uke OEM CDSP | MiCode DT `94c84aeb9e517dbde546fc732033c184094c8e57`; `qcom/cliffs.dtsi` | Existing PAS/FastRPC/translated contexts remain the admitted transport. A DT node does not specify a pixel algorithm. |
| Same-SoC OnePlus | Modules/DT `1138e00fee63582a0cc6a53af3286621786827b7`; display `msm/Kbuild`; EVA `eva_modules.bzl`, `pineapple.bzl`, `msm/eva/msm_cvp_dsp.[ch]`, `msm_cvp_platform.c` | A genuine CVP/CDSP RPMsg protocol exists. The platform table includes `qcom,cliffs-cvp`. The inspected build target is pineapple; its presence is not evidence of a qualified Uke build. CVP commands manage HFI queues, power, sessions and buffers; they are not a DPU composition command. The C/header files are GPL-2.0-only, Linux Foundation/Qualcomm Innovation Center; build-file licensing must be resolved before copying. |
| Current upstream | Linux `f66469d9905b39d2c260a15d7d6db450f4db67c1`; `drivers/misc/fastrpc.c`, `drivers/gpu/drm/msm/disp/dpu1/dpu_{kms,plane}.c` | No DPU-to-CDSP path in these files. FastRPC invocation is private to its driver, with user-process state and ioctl argument handling; there is no exported kernel display submission API. File-level Linux/Qualcomm/Linaro/Red Hat GPL attribution remains with the retained sources. |
| Active accelerator queue | [QDA v4, 1 November 2026](https://lkml.iu.edu/2611.0/00862.html) | Proposed GEM/PRIME and per-session DSP infrastructure, with a compatibility shim. It is not an installed driver or DPU offload implementation. Replacing FastRPC would also affect working ADSP/SSC users and needs independent cumulative qualification. No patch is imported. |

The workspace donor inventory and policy were consulted. Applicable local
donor checkouts absent from this tablet were not treated as inspected. Selected
OnePlus and upstream files were obtained by exact revision; their original Git
blob identities are recorded in `manifests/dpu-cdsp-research-20261106.json`.
No reference scripts or binaries were executed. These are bounded source
findings, not a claim that no implementation can exist elsewhere.

The [FastRPC architecture](https://github.com/qualcomm/fastrpc) separates the
kernel transport from the DSP skeleton and algorithm. A firmware-matched DSP
program remains necessary even if the CPU-side scheduler ultimately lives in
the kernel. Packaging a program differently does not remove this requirement.

## Smallest useful implementation

1. Identify the delayed operation: compositor rendering, plane allocation,
   scaling, display bandwidth, synchronization, or panel/link timing. Record
   GPU completion, atomic commit and presentation times for the same workload.
   An offload must address that measured operation.
2. Qualify one bounded off-screen pixel operation on the actual v73 CDSP
   firmware. Establish the available signed/user PD execution route and exact
   entry point, message layout and module ABI. Compare every output pixel with
   an independent reference. The advertised CVP channel alone does not supply
   an arbitrary filter or scale operation.
3. Implement the memory and completion contract using translated DMA-BUF
   attachments and proper device references. Negotiate format, modifier,
   dimensions, offsets and pitches. Start with an explicitly supported linear
   format; do not interpret UBWC as linear memory. Preserve PAS, VMIDs, both
   SMMU streams and the existing security policy.
4. Add a kernel submission interface only after the real remote operation is
   established. Do not call FastRPC user ioctls from a kernel thread, fabricate
   a user `mm`, or reuse an unrelated CVP opcode. The interface needs bounded
   jobs, cache ownership, input/output fences and remote restart handling.
5. Present a completed output through existing DRM/KMS buffer and fence
   interfaces. An unmodified desktop will not select a new DSP algorithm merely
   because its device node exists. Any unavoidable application integration must
   be specified before claiming automatic desktop acceleration. Keep original
   distribution KDE/GNOME packages.

The Linux [pixel-buffer exchange contract](https://docs.kernel.org/userspace-api/dma-buf-alloc-exchange.html)
and [KMS fencing contract](https://docs.kernel.org/gpu/drm-kms.html)
define the shared-buffer boundary. A DMA address for DPU is not automatically
valid in a CDSP context. A successful RPC is not a display-completion fence.

Failure before dispatch may use the existing path. After dispatch, cancellation,
timeout or remote failure must not release buffers while DSP DMA might continue.
Keep the previous scanout valid and retain affected mappings until completion or
proven remote quiescence. Test teardown, restart and late replies separately.

## Performance admission

For illustration only, a tightly packed 3200 x 2136 XRGB8888 image occupies
27,340,800 bytes. At 120 complete frames/s, each full-frame read or write moves
3,280,896,000 bytes/s before compression or caching. A separate read-and-write
filter can add about 6.56 GB/s while DPU still reads the result. This is arithmetic
under stated assumptions, not measured traffic or the current refresh rate.
It explains why extra DSP work can worsen a memory-limited workload.

The 120 Hz frame interval is 8.33 ms and the 144 Hz interval is 6.94 ms; available
processing time is smaller after rendering and presentation overhead. Admission
requires measured output correctness, frame-time distributions and missed
presentation deadlines, plus sustained thermal/power behavior, against the
existing path at matched modes. A short average-time improvement is insufficient.

## Delivery boundary

No new kernel code, DT property, userspace package, service, boot preference or
hardware capability is enabled by this proposal. There is no driver ready for
physical acceleration acceptance. The first implementation dependency is an
identified and output-checked remote pixel operation, followed by its memory
and scheduling contract.

The separately qualified [FastRPC DMA admission correction](CDSP-KERNEL-DMA-ADMISSION.md)
remains useful transport work and is already in the coordinator's cumulative
source queue. It does not implement this display feature. Future source must
extend the latest complete unstable baseline; only the single coordinator
submits the full kernel, delivers it through COPR/DNF or changes boot state.

## DisplayPort compression requirement

The requested display feature must preserve a working DisplayPort compression
path. [VESA DSC](https://vesa.org/vesa-display-compression-codecs/dsc/)
compresses the transmitted image; FEC protects the compressed link against
transmission errors and is not itself image compression. CDSP pixel processing
must feed a supported DPU buffer format, followed by the existing DPU DSC and
DisplayPort packet/FEC engines. It must not substitute an arbitrary compressed
DSP buffer for a DRM scanout framebuffer. The receiving DP monitor or converter
must advertise and accept the negotiated DSC configuration.

Current project source already includes `dp_dsc.[ch]` and patches 0059/0060/0064,
with capability checks, PPS/byte transport, fresh FEC admission, automatic
selection, receiver health checks and bounded plain-output recovery. The
preparation script includes these layers for Linux 7.3.1. The admitted RGB
implementation uses 8 compressed bpp with 8/10-bpc input and at most two slices;
this is not a claim of every DSC format, compression ratio or topology.
Exact Uke OEM display44275c40, display-DT4a3e1c39 and OnePlus1138e00f provide
the existing attributed hardware contracts. No new DT switch or CDSP runtime
package is needed merely to retain this path.

A separate read-only observation after the coordinator's 12212 boot reports
`uke_dp_dsc=auto`, `dsc_requested=1`, `dsc_active=0`, two lanes at540000kHz,
24-bpp plain transport, and zero current fallback/error values. Automatic
policy is enabled; compression is not active in this observation. The FEC
counter-valid flag is zero, so the zero counter is not enabled-link health
evidence. No capability override or forced compression test was performed.

Earlier Juo trials recorded black compressed output and valid uncorrectable
FEC errors; later source/build fixes and successful plain recovery do not
supersede those failures with a compressed-image success. Physical acceptance
still requires visible static and moving patterns, valid receiver DSC/FEC and
error counters, presentation timing, USB continuity and checked recovery,
first with DP alone and then with internal/external displays together. A
DP-to-HDMI decoder also remains subject to its downstream HDMI bandwidth.

The user subsequently confirms that both DSC/FEC and MEMC/frame interpolation
are required. They have separate acceptance gates. Framebuffer compression such
as UBWC remains a shared-memory layout contract, separate from wire DSC, and
must be supported by every buffer producer/consumer.

## Required MEMC / frame-rate conversion

MEMC must estimate motion and synthesize intermediate frames; merely repeating
or blending frames does not satisfy this requirement. CDSP is a candidate
execution backend, subject to the real v73 program, memory and timing admission
above. No firmware entry point, available algorithm or processing throughput
has yet been established. The bounded Uke OEM display search finds an FRC
reference in the EDID parser, but no MEMC/CDSP implementation in the searched
C/header/DT/build inputs. This does not establish that the stock proprietary
multimedia stack lacks such a feature.

The initial candidate should qualify an off-screen 30-to-60-fps sequence before
integrating display presentation. It needs at least the source frames required
by its chosen algorithm, explicit presentation timestamps, output timestamps,
bounded queueing and an accounted history/look-ahead delay. If the algorithm
needs the next source frame, include that wait in latency measurements. Do not
change display modes, invent source frames or claim 120/144 fps or 4K capability
from a small off-screen test.

Required validation includes:

- Known translated patterns and held-out high-frame-rate references, with
  intermediate frames checked independently of the implementation.
- Occlusion, disocclusion, scene cuts, pans, fast objects, borders and subtitles;
  scene changes must not generate interpolated content across unrelated shots.
- Declared color/transfer/precision handling, actual distinct output frames,
  matched timestamps, audio/video synchronization and end-to-end latency.
- Sustained deadline, memory-traffic, thermal and power measurements, plus
  remote restart, timeout, queue exhaustion and safe buffer retirement.
- Explicit user/caller selection and an original-frame path on unsupported
  content or failure, while preserving ordinary DRM events, fences and input
  latency. No KDE/GNOME fork or separate project compute runtime is introduced.

After MEMC is qualified independently, test its output through both plain DP
and DSC/FEC at supported modes, then repeat with internal/external displays
together. Passing either MEMC or DSC alone does not qualify the combined path.

On the later 12212 read-only check CDSP is offline, consistent with the retained
manual-start policy after reboot. The earlier12211 startup/RPC result remains
historical evidence, not a persistent compute service. No restart or policy
change is made. Both working compressed output and working MEMC remain open;
this document does not supply a runnable implementation of either new feature.

## DisplayPort and HDMI compression algorithms

The user also requires compression for both external interfaces. Implement the
negotiated standard DSC codec wherever the complete physical route supports
it. Preserve the distinction between DP transport compression, converter
decompression and HDMI transport compression:

| Route | Required codec/transport handling | Admission boundary |
|---|---|---|
| DP to a DP receiver | DPU DSC plus DP PPS/FEC, with receiver DSC decoding | Matching DPCD capabilities, admitted slices/bpp, valid receiver health and visible compressed output |
| DP to an HDMI TMDS converter | DP DSC may be decoded by the converter before ordinary HDMI output | Independent DP and downstream HDMI budgets; upstream compression cannot increase TMDS capacity |
| DP to an HDMI FRL/DSC converter | Negotiate the converter's HDMI DSC encode or supported DSC transport path and train FRL | Converter, display and physical link must support the selected HDMI DSC/FRL mode; no inference from DP DSC alone |

[HDMI's specification overview](https://hdmi.org/spec/hdmi2_1) identifies DSC
as link compression and FRL as required for compressed HDMI transport. The
specification version label alone is not proof that a particular device
implements those optional modes. Color subsampling, FEC and MEMC remain
separate features, not interchangeable compression algorithms.

A read-only decode of the current DRM-cached HDMI-route EDID on12212 reports
a320MHz maximum TMDS clock and no HDMI Forum FRL/DSC advertisement. No AUX or
monitor control command is sent. Earlier route evidence reports an LT8712SX
family DP-to-HDMI2.0 converter, DSC decoding and no PCON DSC encoder advertised;
its exact installed revision/firmware remains unidentified. The manufacturer's
previously retained U2 R1.0 brief supports that DP-decode-to-HDMI distinction;
the attempted public PDF refresh times out during this follow-up. None of
these observations qualifies compressed output or a converter firmware change.

Current upstream Linuxf66469d9 provides `drm_dp_pcon_frl_*` and
`drm_dp_pcon_dsc_*` helpers in `drivers/gpu/drm/display/drm_dp_helper.c`
(original Git blob488fd123a01adb7c063d14e3952370726a3b65d6). They are useful
reference interfaces for supported converters, not evidence that this
converter implements FRL or an HDMI DSC encoder. Existing Uke source/DT and
same-SoC OnePlus comparisons remain the hardware baseline; no new board
resource, converter command, codec implementation or driver is imported.

Keep the existing TMDS guard, and reject modes outside the actual downstream
budget even if their compressed DP budget fits. For an FRL/DSC-capable route,
future implementation must admit both endpoint capabilities, the converter's
DSC parameters, FRL link training, output state and error handling. Qualify that
route separately with known images, reconnect/recovery and MEMC enabled and
disabled. Unsupported HDMI DSC must be reported as unsupported rather than
advertised from a software-only capability flag. CDSP remains a possible
pixel/MEMC producer; it does not manufacture a missing HDMI transmitter feature.
