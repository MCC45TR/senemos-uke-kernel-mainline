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

Automatic userdata kernel activation remains held. The existing A/B state model
does not implement a qualified alternating slot writer. Physical first boot,
selector forwarding and interrupted-update fallback remain separate tests.
