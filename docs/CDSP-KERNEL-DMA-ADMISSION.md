# Kernel FastRPC DMA admission

6 November2026, POCO Pad X1. Current12211 boots CDSP and binds both translated
FastRPC context banks after a manually admitted startup. No separate compute
runtime package is added. A functional arithmetic workload remains unverified.

Actual Linux7.3.1 fastrpc_cb_probe() publishes valid sessions, duplicate entries
and driver data before dma_set_mask(). A rejected DMA mask therefore leaves
an allocatable session on a device whose probe failed. A concurrent opener
can also observe that session before DMA admission completes. The narrow patch
configures the existing domain-specific mask first, outside the spinlock,
then publishes sessions under the original lock. DMA failure preserves the
previous table, count and driver data. Domain masks, SIDs, duplicate policy,
PAS, secure-channel admission, VMIDs, DT, SMMU translation and manual startup
policy are unchanged. A full session table can now be checked after DMA setup;
it still returns ENOSPC without publishing a session.

This is a source-level failure correction, not an observed cause of a current
CDSP crash. It does not add a DSP program, HVX/HMX backend, automatic startup
or generic kernel arithmetic service. Native FastRPC remains the compute ABI.

Exact comparisons: MiCode kernel5712080a and DT94c84aeb; same-SoC OnePlus
kernel fc892483 and modules/DT1138e00f; Linux7.3.1/79a90760 and current upstream
f66469d9. Both OEM generic FastRPC callbacks have the same DMA-publication
order. The Linux files retain their Linux Foundation/Linaro/Qualcomm GPL-2.0
attribution. The callback controls are extracted Linux code, also GPL-2.0.
No donor scripts or binaries are executed, and no board resource is copied.

Vinayak Katoch's21 October v6 CB-lifecycle proposal is an active comparison:
https://mail-archive.com/dri-devel@lists.freedesktop.org/msg645820.html
It changes child-device creation and duplication. It is not imported here;
the existing native platform-driver DMA/IOMMU supplier path is preserved.
The publication error is independently checked against the actual callback.

The COPR fixture runs401 domain/fault/table-boundary cases in four compiler/
sanitizer modes, requires the original and two mutants to fail, retains the
coherent-buffer lifetime tests and builds a complete AArch64 FastRPC object.
Its defconfig object is independent source evidence, not a full cumulative
kernel or proof that the patch is running on the tablet. Following integration
must apply this layer over complete12211 and every qualified peer handoff,
then repeat cumulative configuration, source, Image, signing and device gates.
Only the coordinator owns that full kernel/delivery queue.
