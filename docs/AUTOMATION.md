# Source verification and automatic COPR builds

The development channel is [mcc45tr/uke-linux-test](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-test/), initially limited to Fedora Rawhide AArch64. COPR clones this repository's `main` branch and invokes `.copr/Makefile` using its documented `make_srpm` method. Official Fedora host tools verify the source archive's SHA-256 and detached OpenPGP signature before creating the SRPM. Binary builds run without network access. The ordinary `Makefile` also supports local source generation.

Push webhooks request a rebuild when reviewed source changes reach `main`. The daily GitHub workflow queries Kernel.org's stable feed and COPR's build history. It avoids submitting the same reviewed version while a build is active or successful. The custom webhook URL is stored only as the repository secret `COPR_KERNEL_BUILD_HOOK`; no credentials belong in source, manifests or reports.

A new stable version needs its own `manifests/linux-VERSION.json`, signed source identity, Uke patches and config hashes. An unsupported stable release stops tracking with an explicit error. The workflow cannot silently replace the Uke port with generic ARM64 or reuse a different version's adaptation. After that version's reviewed profile and packaging version are committed, source generation downloads the matching stable archive automatically.

The host-only official COPR client used for publication is `copr-cli-2.7-1.fc46.noarch` with `python3-copr-2.8-1.fc46.noarch`. This upstream Python client implements the authenticated upload API; it is neither a project script nor a target dependency. RPM build policy tools may also use Fedora's host Python. The target RPMs and their tested AArch64 runtime closure exclude Python.

The local container and COPR worker are separate environments. COPR's Fedora source-generation chroot and Rawhide repository packages can advance independently of the local pinned image. Each COPR job retains its source RPM, tool versions and build logs. Neither automation nor a successful package build proves Uke boot, firmware handoff or peripheral operation.

Kernel subpackages retain Fedora's installonly policy across different upstream
versions. Packaging revisions of the same version share a module directory and
must replace each other. Version-equality `Obsoletes` entries omit the RPM release
to replace only that upstream version's earlier revisions. Actual upgrade checks
require one installed revision per subpackage; host fixtures separately check
that a different upstream version remains installed. This follows RPM's
[dependency version matching](https://ftp.rpm.org/api/4.4.2.2/dependencies.html)
and does not select a boot entry.

References: [COPR source methods and webhooks](https://docs.pagure.org/copr.copr/user_documentation.html), [Kernel.org stable feed](https://www.kernel.org/releases.json).
