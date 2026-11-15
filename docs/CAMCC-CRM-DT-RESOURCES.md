# Permanent CAMCC resource topology

13 November 2026. The accepted kernel24 parent is source6719b05e,
COPR11309609. This source step extends its actual early FDT converter; it does
not activate CRM, publish a new camera or change the running device.

The native controller previously retained CC_BASE and the CRM configuration
window only. It now receives a separate CRMC window and the original rising
GIC SPI121 interrupt with its validated interrupt-controller phandle. The
configuration resource retains the name `crm` for the current admission guard;
the added vote window is named `crmc`. The old CRM and CRMC syscon nodes are
disabled together. Unknown CRMC consumers, altered regions, driver IDs, IRQ
tuples or interrupt domains are rejected before graph mutation. The accepted
two-window native layout remains an explicit migration input; repeat conversion
must preserve the complete synthetic FDT byte for byte.

These are exact Uke OEM values from MiCode/kernel_devicetree
94c84aeb9e517dbde546fc732033c184094c8e57, qcom/cliffs.dtsi: configuration
0xadd7000/0x2000, CRMC0xadda000/0x2000, software driver0 and hardware drivers0..2.
The source also retains the original CRMB/CRMV layout validation. No values from
an adjacent board are substituted. The existing camera CRM source review pins
the exact Uke driver and the same-SoC OnePlus implementation; their reviewed
CAMCC code matches. Linux GIC/OF conventions determine the IRQ representation,
not a new board-specific interrupt protocol.

COPR qualification exercises the actual converter with GCC/Clang ordinary and
address/undefined sanitizer builds. It retains the old graph/refusal tests and
adds native-layout upgrade, complete CFG/CRMC, IRQ/domain, driver-ownership and
unknown-consumer cases. The report is text only and is not a device dependency.
No native test result or full-kernel result is claimed before its receipt.

The firmware-enabled CRM refusal remains unchanged. Permanent mapping and IRQ
lifetime, all38 managed clock objects, parent snapshots and inherited AP votes
must be completed and qualified before activation. Both calibrated cameras,
rear focus/parking, normal cumulative delivery and hardware acceptance remain
open. This patch is one part of the kernel/DT migration, not camera completion.
