# Linux 7.2.9 Uke adaptation

The first seven patches are derived from the public Uke Linux 6.12
port at `32cad9ccd383ff4b37d8a5e7f88a8bfdcc07307e` by
[ztsubaki](https://github.com/ztsubaki/uke-linux), specifically
`patches/uke/0001-uke-platform-and-usb-port.patch`. Preserve each source file's
Qualcomm/Linux copyright and SPDX license. The original OEM source identity is
recorded in the workspace source catalog. Reference clones are never modified
or executed by the build entry point.

The eighth patch adds the dedicated `qcom,sm7675-qmp-ufs-phy` profile from
Xiaomi's `5712080a4b0c0b1a879e6d145c601c649ddaddfd` OEM Cliffs-compatible
PHY driver. It uses the current upstream QMP implementation, preserving the
OEM effective tuning for both lanes, Gear 4/5 and Rate A/B. The UFS board node
remains disabled until its GCC/GDSC, NoC, supplies, reset and SMMU chain has been
ported and validated. The complete eight-patch Linux 7.2.9 build passed Image,
DTB, 1,146 module, RPM/SRPM and AArch64 package lifecycle checks on October 6.
See the [build record](../../reports/FIRST-CONSOLE-KERNEL-BUILD-2026-10-06.json).
This establishes buildability, not a working board UFS link.

The target base is Linux `v7.2.9`, commit
`5fce161649b4d779d1b76d9fcd52dc77779774b8`. Reviewable differences from the
6.12 donor include current pointer-linked interconnect nodes, preserving new
upstream clocks and tests, and using the current DWC3 glue/probe API. The
upstream generic eUSB2 PHY/repeater and DWC3 core stay at their current
implementations. The Uke legacy PHY/repeater and fixed WCD939x route remain
separate, rebuilt drivers; Android vendor modules are never included.

This is a **source-build candidate**. It is not a complete hardware port or a
physically accepted UEFI boot image. The independent DTS contains Uke MPIDRs,
GIC and firmware static reservations. TLMM is described but disabled pending
profile-specific handoff acceptance. Storage, DRM, touchscreen, wireless,
audio, sensors and charging need further Uke development. The future UEFI
loader must supply exact RAM and dynamic reservations; never boot this tree
by assuming the China source evidence matches the installed Global firmware.
RPM scriptlets only update module dependency indexes, not Android partitions
or the default boot entry.

Host exceptions: Fedora's upstream RPM/package-management stack can pull in
Python during toolchain construction. It is recorded in the build environment
package inventory and never copied into target RPMs. Kernel compilation and
project automation use Kbuild/C/Bash; no project-owned Python is introduced.
