# MST per-stream RGB depth candidate

The current cumulative MST path fixes every stream at 24bpp, while the SST
path supports ten-bit output. Changing only connector metadata would leave
payload bandwidth and DPU packing inconsistent. This source candidate keeps
the selected bpp in a subclassed DRM connector atomic state and uses it for
PBN, DP programming and the matching DPU output format.

Standard `max bpc` requests can select ten when EDID, negotiated link, downstream
TMDS and port PBN admit it. The prior eight-bit default remains. The generic
DRM MST atomic check still owns aggregate topology admission and can reject an
oversubscribed pair. Automatic cross-stream quality arbitration is not added
by this patch; userspace may retry with a lower ceiling. No current working
SST mode, default, board resource or rollback mechanism changes.

Connector reset, duplicate and destroy use the standard DRM state-lifetime
helpers. A live ceiling change requests a full modeset; a failed slot allocation
does not publish a new selected depth. Each connector retains its own state,
so one stream's format cannot be inferred from the shared SST panel. The DP
programmer rejects an unavailable selection instead of silently sending a
different format. Source/native fixtures cover these actual callbacks, not
only a detached arithmetic model.

MST HDR, colorspace conversion, DSC/FEC, external VRR and per-stream audio are
still separate open work. Existing HDR/DSC refusal paths remain. The attached
direct monitor is SST; its successful 75Hz/10bpc image is not an MST test. A real
two-output branch is required for physical acceptance, including independent
8/10-bit streams, aggregate limits, live switches, hotplug, DPMS, suspend,
closed-cover operation, failed payload rollback and audio continuity.

## Source comparisons

- Exact Uke OEM display `44275c404a677d9d9e5230fedd1af2ef02fc7b9a`,
  `msm/dp/dp_mst_drm.c` blob
  `d42e9d0f6786332e1ebbf95b06bda3520880da9b`: PBN derives from per-stream
  timing bpp; DSC/FEC overhead and HDR use downstream SDE-specific contracts.
  The original GPL-2.0-only/Qualcomm/Linux Foundation/Red Hat notices remain.
- Same SM7675 OnePlus modules/DT
  `1138e00fee63582a0cc6a53af3286621786827b7`,
  `vendor/qcom/opensource/display-drivers/msm/dp/dp_mst_drm.c` blob
  `ef3fa1e0254cb6f3272c70e0c7be8517727664d5`: the same timing-bpp ownership
  pattern, not a portable mainline connector or firmware implementation.
- Linux 7.3.3 `d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`,
  `drivers/gpu/drm/display/drm_dp_mst_topology.c` and
  `drivers/gpu/drm/drm_atomic_state_helper.c`: standard PBN/slot/aggregate
  checks and subclassed connector lifetime. Current Uke source already carries
  Qualcomm MST v7 and IRQ_HPD v8; they are retained rather than rewritten.
- The admitted source56 SRPM and actual resulting source profile are the
  cumulative parent. The old repository `native.config` or historical status
  documents are not substitutes for the resolved candidate configuration.

No donor script is executed, no foreign board clocks/registers are copied and
no new firmware, userspace daemon, package family or compositor fork is added.
Compile/object results remain separate from full module/Image and device tests.
