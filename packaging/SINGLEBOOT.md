# Uke singleboot kernel profile

20 October 2026 · Fedora Rawhide AArch64 · Uke / SM7675.

`senemos-uke-linux-kernel-mainline-singleboot` selects the Android v4 container
with `senemos.root=userdata`. It requires the exact matching core, modules,
DTBs and boot bundle from `senemos-uke-linux-kernel-mainline`. Sharing these
signed packages preserves one kernel ABI and avoids a second kernel build.
The ordinary mainline profile retains the `linux` partition boot container.

The singleboot package publishes `/usr/lib/senemos/default-boot.img` for the
image composer and an auditable profile descriptor. The first-boot classifier
records the actual mounted physical partition, rather than trusting the package
name. No package script writes storage, changes the active slot or reboots.

Automatic alternating-slot activation and interrupted-update fallback remain
unqualified. The separately packaged current-slot activation path requires its
own preflight, backup and readback; installing this descriptor performs none
of those operations.


The exact current tuple is recorded in the installed JSON descriptor.
The common kernel and physical acceptance retain their separate evidence.
# Unstable Linux 7.3 userdata profile, 21 October 2026

`senemos-uke-linux-kernel-mainline-unstable-singleboot` requires the exact
7.3.0-1 unstable kernel tuple. Its descriptor is
`/usr/share/senemos/uke/unstable-singleboot.json`; its separate symlink is
`/usr/lib/senemos/unstable-default-boot.img`. It preserves the ordinary boot
default and shares the unstable Image, modules, DTB and userdata boot image.
Installation performs no activation, partition write, slot selection or reboot.
Image composition, boot and physical acceptance require separate validation.
