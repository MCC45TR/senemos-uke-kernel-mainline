# Stock-ABL boot-specific adaptation

This directory is separate from the accepted `patches/7.2.9/series` RPM port.
The Fedora image builder applies its one additional patch only to an isolated,
verified Linux 7.2.9 tree with all 13 accepted patches already present.

`0001-arm64-uke-abl-dt-hook.patch` connects the reviewed early DT adaptation in
`src/boot/uke-abl.c`. Preparation embeds the two source-pinned UFS and USB
peripheral overlays, supplies the exact matching upstream complete libfdt
checker and generates a kernel parser wrapper for the upstream overlay code.
Upstream checker attribution and hash are in `src/boot/vendor/source.json`.

The same isolated boot adaptation admits the OEM `smpb2`, `ldod1`, `ldob5`,
`ldob12` and `ldod3` resources required by the complete UFS host/PHY supply
graph. The earlier six-resource experiment rejected them before registration.
The eight-resource trial bound the first two but still waited for `ldob5`.
Existing command-DB validation, regulator
types, voltage constraints and unrelated-resource rejection are retained.
The evidence is OEM Cliffs DT commit `94c84aeb9e517dbde546fc732033c184094c8e57`
and the matching regulator driver from kernel commit
`5712080a4b0c0b1a879e6d145c601c649ddaddfd`. Silent SMMU handoff rejections now
report their original error and hardware capability/context-bank condition;
translation and firmware-display preservation guards are unchanged.

`tests/boot-supplier-contract.sh` compiles the actual prepared supply-admission
branch and checks all eleven allowed resources and unrelated names. The image
builder freezes and runs this host-only test before compiling the kernel.
The same test compiles the actual SMMU stream-admission branch: USB/GPI remain
valid in the USB-only match; UFS and GENI0 require the boot-specific match;
display and unrelated streams remain rejected.

The incoming bootloader-selected FDT stays intact. The admitted copy keeps
runtime RAM ranges and reservation addresses, prepares UFS/USB providers and
derives the simplefb address from the live splash reservation. It requires the
reviewed Uke model, Cliffs-MTP compatible and board ID. Generic foreign boards
are left unchanged; malformed matching Uke graphs are rejected.

The adapted graph admits only the exact UFS, USB wrapper, GPI0 and GENI0 clients of
the scoped apps SMMU. Other OEM consumers are disabled, retaining their IOMMU
specifiers. In particular, the OEM display context devices must not reclaim
the reserved firmware display streams: the allocator returns `-EBUSY`, which
propagates through bus probing and unregisters the whole SMMU. Disabled clients
cannot bypass translation; the display continues through the preserved firmware
mapping and simplefb. GENI0's OEM `0xa3` stream is required by the parent of
the I2C controller used by the USB repeater. Removing its IOMMU property would
permit unreviewed DMA: upstream GENI also maps DMA buffers against the wrapper.
Host tests cover all four admitted identities, enabled I2C/repeater ancestry,
preserved display specifiers/handoff and invalid UFS/GENI DMA specifications.

The fixed-peripheral boot overlay also disables both OEM PMIC-GLINK platform
nodes and the legacy UCSI connector endpoint. Their nested OEM children do not
implement the upstream connector binding. Actual Uke journals show UCSI and
altmode probe Oops while formatting a missing `reg` property, plus duplicate
auxiliary registration from the OEM log node. This bring-up profile does not
claim UCSI, USB role switching or Linux charging control. The translated USB
controller/PHY/repeater route remains enabled; host tests verify the exact gate.

The reboot-reason overlay uses the existing upstream NVMEM reboot-mode driver.
Input admission checks the complete PMK8550 SDAM provider path, referenced
one-byte cell at offset `0x48` and bit range `<1 7>` before preserving that cell
reference. OEM mode values are normal `0x20`, recovery `0x01` and bootloader
`0x02`. No custom reboot wrapper, raw PMIC write or OEM panic notifier is added.
The adapted model displays the owner-requested `Xiaomi Pad 7`; the original
factory model/board admission remains unchanged. Host fixtures reject a wrong
cell, offset or bit range. A physical `reboot bootloader` transition requires a
matching built candidate and its own acceptance record.

The first sustained physical v5 TTY additionally requires the scoped CoreSight
autoload containment supplied by `uke-boot-integration` release 5. A kernel-only
source change does not install that root policy or qualify broader hardware.

Host fixtures use the same transform and kernel libfdt sources. A real Image,
all modules and DTBs must compile, and final module bytes must match the signed
RPM payload before the paired Fedora root is composed. Host checks and generic
VM boots do not qualify Qualcomm ABL, UFS, panel, input or USB power. No captured
unit DT, RAM map, calibration data or firmware binary is embedded in this patch.
