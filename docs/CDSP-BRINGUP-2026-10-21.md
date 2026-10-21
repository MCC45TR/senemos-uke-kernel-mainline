# Cliffs CDSP integration — 21 October 2026

Environment: POCO Pad X1, SM7675, Fedora Rawhide AArch64. Running 7.2.11-17
has ADSP and WPSS remote processors, but its CDSP and NSP providers are unbound.
HTP v73 is identified by the pinned Qualcomm backend catalogs; no native NPU
operation has been verified.

## Implemented source

The 7.2.12-2 candidate patch 0099 registers the OEM NSP interconnect provider
and connects its compute master through GEM, LLCC and EBI. It retains the
two-channel, 32-byte widths, GEM QoS ports 0x37000/0x77000, priority zero,
disabled urgency forwarding and enabled priority override. CO0 has the exact
two NSP members and enable mask one; the GEM master joins HLOS SH1. The PCIe
edge requires its own native provider and is not represented by a dangling link.

The existing native preparation gate now compiles and checks this actual C
graph. Its legacy mode retains the earlier package-entry contract. The test
checks endpoint IDs, reachable DDR/configuration paths, BCM membership, QoS,
and all retained QUP/LPASS/GPU/USB/UFS routes. Native display preparation retains
both the display and compute members in SH1. All four combinations with and
without NSP/native display pass; the legacy native driver remains byte-identical
to the original 98-patch preparation. Wrong native routes and membership are
rejected. Actual AArch64 compilation with Clang 23.1.3 and warnings as errors
passes against the exact signed 7.2.12 source preparation, using a separate
configuration/output directory. These are host results.

Patch 0100 corrects the LLCC probe's optional-aperture handling. The admitted
Cliffs7 graph has four banks and a broadcast window, with no sixth broadcast-AND
window. Running 17 reports an invalid-resource error from this unnecessary
mapping attempt while remaining bound. The corrected source avoids the access;
the host probe regression rejects every sixth mapping attempt and retains all
238 write-failure cases, activation failures and unrelated-SCID preservation.
The ordinary broadcast polling fallback is unchanged. Other SoCs retain their
existing mapping/error behavior. No cache policy or voltage value changes.

The retained Global OS3.0.304.0 extraction includes an ELF32 Qualcomm DSP6 v73
HTP skeleton and an AArch64 HTP v73 stub. The latter requires Android `libc.so`,
`liblog.so` and `libcdsprpc.so`; the CDSP daemon requests `/system/bin/linker64`.
They are ABI evidence, not Fedora binaries. No proprietary component is copied,
executed, repackaged or qualified for redistribution by this source change.
The extracted vendor/ODM files contain no named CDSP boot image; the separate
OTA modem/DSP partitions still require inspection.

## Source comparison and attribution

All modified upstream driver files retain their GPL-2.0-only notices and
Qualcomm attribution. Reference code is inspected as text, not executed.

| Source | Exact revision and files | Use and compatibility limit |
|---|---|---|
| Xiaomi Uke kernel | `5712080a4b0c0b1a879e6d145c601c649ddaddfd`, `drivers/interconnect/qcom/cliffs.c`, `include/dt-bindings/interconnect/qcom,cliffs.h`, `drivers/remoteproc/qcom_q6v5_pas.c`, `drivers/soc/qcom/llcc-qcom.c` | Exact NSP nodes, QoS, BCMs, PAS and LLCC contract; Android consumer APIs differ |
| Xiaomi Uke DT | `94c84aeb9e517dbde546fc732033c184094c8e57`, `qcom/cliffs.dtsi` | Exact NSP provider and two LLCC regions; retain stock board resource identity |
| OnePlus SM7675 | `fc892483f1d61f245924681eb5abd563564d9cba`, `drivers/interconnect/qcom/cliffs.c` | Byte-identical topology to the Xiaomi file; not an independent tablet result |
| Palawan native Linux | `0d9f7fdf720ae9f4ecfbee4fadaf1e3b5c442e95`, `drivers/interconnect/qcom/palawan.c`, `drivers/remoteproc/qcom_q6v5_pas.c`, `arch/arm64/boot/dts/qcom/palawan.dtsi` | Pointer-link RPMh example; do not transfer its automatic boot, board graph or memory-assignment policy |
| Upstream Linux | `4056b3c9d3c92ea45955641dbafeb9b960e146ef`, `drivers/interconnect/qcom/icc-rpmh.c`, `sm8550.c`, `drivers/remoteproc/qcom_q6v5_pas.c`, `drivers/soc/qcom/llcc-qcom.c` | Native APIs, PAS lifecycle and optional broadcast fallback; no exact Cliffs CDSP descriptor |

## Remaining integration and acceptance

1. Resolve the exact owner CDSP/DTB firmware and Linux AArch64 userspace ABI.
   An Android library or another SoC's firmware is not an admissible substitute.
2. Implement the exact PAS 18/DTB 0x25, CX/MXC/NSP proxy and AOP load-state
   contract, including DDR/crypto votes and failure unwind. Existing ADSP/WPSS
   consumers must retain their two-supply behavior.
3. Validate firmware, DTB and global-sync carveouts, permissions and SCM
   ownership before assignment. Upstream PAS can assign memory during probe;
   `auto_boot=false` alone does not make a new binding harmless.
4. Translate only the exact Uke GLINK/SMP2P and CDSP FastRPC context-bank graph;
   prove SID and IOMMU isolation. An unused character node is not acceptance.
5. Build one matched signed COPR tuple, audit it, install through DNF, and use
   the existing guarded updater with a retained recovery baseline.
6. Run reference-result HTP v73 computation on the tablet. Verify precision,
   cancellation, malformed requests, concurrent jobs, remote crash/recovery,
   cold start, runtime PM, suspend/resume, coherency, thermal and energy behavior.

The 7.2.12-2 candidate has not been submitted to COPR, installed or booted. No CDSP
firmware request, memory assignment or remote-processor start is performed by
this work. NPU, new bandwidth-path operation and LLCC warning removal remain
unqualified on hardware.
