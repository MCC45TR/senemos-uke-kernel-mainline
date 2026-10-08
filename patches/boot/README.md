# Stock-ABL boot-specific adaptation

This directory is separate from the accepted `patches/7.2.9/series` RPM port.
The Fedora image builder applies its one additional patch only to an isolated,
verified Linux 7.2.9 tree with all 13 accepted patches already present.

`0001-arm64-uke-abl-dt-hook.patch` connects the reviewed early DT adaptation in
`src/boot/uke-abl.c`. Preparation embeds the two source-pinned UFS and USB
peripheral overlays, supplies the exact matching upstream complete libfdt
checker and generates a kernel parser wrapper for the upstream overlay code.
Upstream checker attribution and hash are in `src/boot/vendor/source.json`.

The incoming bootloader-selected FDT stays intact. The admitted copy keeps
runtime RAM ranges and reservation addresses, prepares UFS/USB providers and
derives the simplefb address from the live splash reservation. It requires the
reviewed Uke model, Cliffs-MTP compatible and board ID. Generic foreign boards
are left unchanged; malformed matching Uke graphs are rejected.

Host fixtures use the same transform and kernel libfdt sources. A real Image,
all modules and DTBs must compile, and final module bytes must match the signed
RPM payload before the paired Fedora root is composed. Host checks and generic
VM boots do not qualify Qualcomm ABL, UFS, panel, input or USB power. No captured
unit DT, RAM map, calibration data or firmware binary is embedded in this patch.
