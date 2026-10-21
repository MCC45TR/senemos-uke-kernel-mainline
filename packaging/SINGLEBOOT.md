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

Release 17 requires the exact `7.2.11-17` shared tuple from COPR 11181181.
The profile contains metadata and its default-container link; Image, modules
and DTBs retain their common build identity. The common build is pending at
this source checkpoint. Its firewall/root-policy source, objects and fresh
preparation pass. Release 17 adds the retained root-selector capability and
guarded updater dependency, an independent SDP adapter query and the explicit
upstream per-CPU workqueue. Complete signed artifact and tablet acceptance remain
separate gates. Automatic full-userdata F2FS growth is not included in this
kernel release. This profile does not enable automatic activation or the
private VRR experiment.
