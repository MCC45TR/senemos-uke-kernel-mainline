# Uke Cliffs CDSP kernel candidate

4 November 2026: kernel7.3.1-2313 succeeds in COPR11252339. All833 module
signatures and complete-package checks pass. The six published RPMs also pass
independent signature/digest checks. Administrator installation, firmware
preflight and physical compute acceptance remain open.

The exact Uke descriptor uses primary PAS 18, DTB PAS 0x25, three ARC proxy
rails, the existing firmware/DTB carveouts and HLOS/CDSP global-sync memory.
The converter admits the retained root and user contexts with unmasked SIDs
0x0c01 and 0x0c02. It preserves native secure-channel policy and translated
DMA; it adds no remote heap, arbitrary VMID or blanket SMMU bypass.
OEM PD values are conversion identity checks; native FastRPC uses generic
session allocation. Exact root/user execution and secure-device policy still
need the first listener, shell and translated-buffer qualification.

Failed start and partial transport start use the same retryable stop
transaction. Refused secure shutdown retains mappings, tables, proxy ownership
and the original remoteproc power reference. New boots are refused during
pending cleanup. The boot-FDT CDSP instance has a permanent platform driver:
unbind is suppressed and the shared PAS module is retained until reboot.
Other PAS instances keep their existing bind/unbind interfaces.

Firmware names are qcom/uke/cdsp/cdsp.mdt and cdsp_dtb.mdt, with their matching
split segments. These private OEM files are absent from the candidate source
and COPR inputs. Native compilation never runs on the tablet.

Automatic CDSP boot remains disabled while firmware and device acceptance are
unqualified. A controlled sysfs remoteproc start is required after provisioning.
The native FastRPC devices appear only after the GLINK channel is running.
Actual Hexagon workloads also require a compatible DSP shell, userspace
FastRPC/fileservice and DSP program/runtime. A kernel match does not provide
an arbitrary CPU-to-DSP compiler or establish QNN/HMX functionality.

Sources: exact MiCode kernel 5712080a4b0c0b1a879e6d145c601c649ddaddfd,
MiCode DT 94c84aeb9e517dbde546fc732033c184094c8e57 and upstream Linux 7.3.1.
See the canonical CDSP and Focus input engineering lessons for prior source
comparisons and the separate hardware acceptance boundary.
