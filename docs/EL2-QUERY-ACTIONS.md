# Uke EL2 service query candidate

3 November 2026. This Actions artifact boots `7.3.1-2001-kvm`, based on the
retained `7.3.1-1300` source package from COPR build `11251037`. It retains that
package's O82 supplier selection, native touch and platform adaptations. The
only new firmware operation is one SCM INFO query about BOOT command `0x21`
after the SCM driver initializes. No Gunyah exit is requested. Normal EL1 entry
remains supported; this candidate does not require an existing EL2.

Compilation and source/ABI/module-signature checks run on the native AArch64
Actions runner. Upstream Linux/dracut/dt-schema build dependencies, including
upstream Python tools, are confined to that runner. No Python is included in
the target payload. Nothing is submitted to GitHub Releases or a package
repository. Artifact availability lasts 14 days.
The branch's COPR source entry refuses this manual candidate, so a source
webhook cannot publish it through the ordinary KVM package lane.

## Files and installation

`boot-userdata.img` selects `PARTLABEL=userdata`; this is the root used by the
recorded Fedora installation. `boot-linux.img` selects `PARTLABEL=linux` for a
separately provisioned installation. Both contain the same query kernel and
matching early initramfs modules. `rpms/` contains the matching full module set
and kernel files, with no boot-activation scriptlets. KVM aliases and metadata
are isolated from the normal kernel family.

Verify the extracted artifact on the computer:

```sh
sha256sum -c SHA256SUMS
```

Before switching kernels, install its matching packages on Fedora:

```sh
sudo dnf --nogpgcheck install ./rpms/*.rpm
```

These are unsigned experimental Actions RPMs; their checksums bind them to
this artifact. Kernel modules retain the kernel's enforced module signatures.
Package installation does not flash an image, select a slot or reboot.

Use the verified Linux boot slot and the existing recovery route when flashing
the selected image from the computer. Do not infer the slot from a filename.
For a userdata installation, the fastboot operation is:

```text
fastboot flash boot_<verified-Linux-slot> boot-userdata.img
```

The artifact contains no replacement HYP, TZ, XBL, devcfg, partition table or
calibration payload. Do not overwrite the known working recovery/rollback slot.

## Collect the result

After booting the candidate, run:

```sh
uname -r
sudo sh collect-el2-query.sh > el2-query-result.txt
```

Expected release: `7.3.1-2001-kvm`. The snapshot is also available at
`/sys/bus/platform/devices/*/uke_el2_query`, with a `UKE_EL2_QUERY:` kernel log
message. Reads return the existing snapshot and never repeat the SCM request.

`transport=0` plus `availability=advertised` means firmware advertised the
queried service at SCM probe. `not-advertised` is a negative advertisement in
that phase. A nonzero transport result leaves availability `unknown`; retain
the error and all three returned words. None of these outcomes establishes
permitted early-boot timing, a successful transfer or working KVM guests.
`current_el` describes Linux at the query; `boot_hyp_available` separately
reflects Linux's saved boot-mode state. `exit_requested=0` is expected.

If Fedora does not start, preserve the existing recovery route and collect
the early `UKE_EL2_QUERY:` message if available. This experiment has no physical
boot or EL2 acceptance until that device evidence is reviewed.
