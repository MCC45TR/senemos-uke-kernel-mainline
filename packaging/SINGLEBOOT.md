# Uke unstable singleboot kernel profile

21 October 2026 · Fedora Rawhide AArch64 · Xiaomi Pad 7 / POCO Pad X1 (`uke`, SM7675).

`senemos-uke-linux-kernel-mainline-unstable-singleboot` requires the exact
`7.3.0-1` package set from `senemos-uke-linux-kernel-mainline-unstable`.
It shares the common Image, modules, DTB and Android v4 boot container; it
selects the userdata container with `senemos.root=userdata` and F2FS.

The package publishes `/usr/share/senemos/uke/unstable-singleboot.json` and
`/usr/lib/senemos/unstable-default-boot.img`. The latter links to
`kernel-updates/7.3.0-1-unstable/userdata.img`. The ordinary boot default remains
independent. The installed JSON descriptor records the exact kernel tuple.

No package script activates a kernel, writes storage, changes the active slot
or reboots. Image composition, boot and physical acceptance require separate
validation. Automatic userdata slot updates and fallback remain unqualified.
The common kernel's RPMh read compatibility limit remains applicable.
