# Build the Uke kernel

The 7.3.5 branch targets Fedora Rawhide AArch64. COPR builds through
`.copr/Makefile` and [the kernel RPM recipe](../../packaging/rpm/kernel/).
The worker verifies and unpacks the signed parent, checks the cumulative
delta and derives the Linux version from the upstream archive.

Run the source layout check from the repository root.

```sh
make validate
```

Run `make verify-sources` with Bash, curl, GnuPG, jq, Git, RPM and cpio to
verify the signed parent, source layout and expanded RPM ABI metadata.
`UKE_COPR_PARENT_SRPM` can point to an existing copy of the parent SRPM.
The same checksum and signature checks apply to a local copy.

COPR workers use `make -f .copr/Makefile srpm outdir=...`. The worker rejects
an RPM revision that already has a successful published build. Advance the
signed parent and release plan when preparing a new revision.

The [7.3.5-46-era checkout](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/a7680f9fe776502c104d412ecbb94688e21a8431)
preserves the earlier preparation tools, profiles and fixtures at their
original paths. The [KVM branch](https://github.com/MCC45TR/senemos-uke-kernel-mainline/tree/kvm)
owns the experimental EL2 producer.
