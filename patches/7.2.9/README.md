# Linux 7.2.9 Uke adaptation

The ordered seven-patch series is derived from the public Uke Linux 6.12
port at `32cad9ccd383ff4b37d8a5e7f88a8bfdcc07307e` by
[ztsubaki](https://github.com/ztsubaki/uke-linux), specifically
`patches/uke/0001-uke-platform-and-usb-port.patch`. Preserve each source file's
Qualcomm/Linux copyright and SPDX license. The original OEM source identity is
recorded in the workspace source catalog. Reference clones are never modified
or executed by the build entry point.

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
