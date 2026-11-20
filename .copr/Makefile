SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: srpm
srpm:
	if [[ "$(spec)" == *packaging/copr/normal-kernel/senemos-uke-linux-kernel-mainline.spec || "$(CURDIR)" == */packaging/copr/normal-kernel ]]; then
		dnf -y --setopt=install_weak_deps=False install curl jq gnupg2 rpm-build cpio git-core xz tar coreutils
		bash "$(dir $(abspath $(lastword $(MAKEFILE_LIST))))../packaging/copr/normal-kernel/build-srpm.sh" "$(outdir)"
		exit
	fi
	version=$$(sed -n 's/^version := //p' Makefile)
	bash scripts/require-unstable-series.sh "$$version"
	# COPR runs source generation as root in its isolated Fedora mock chroot.
	dnf -y --setopt=install_weak_deps=False install make curl jq gnupg2 xz tar rpm-build coreutils git-core gcc gcc-c++ dtc libfdt-devel clang compiler-rt
	# COPR collects this directory as an unprivileged user. Keep verification
	# state and the private-mode GPG home in the source workspace, not outdir.
	$(MAKE) -f Makefile srpm outdir="$(CURDIR)/build/copr-source"
	mkdir -p "$(outdir)"
	install -m644 build/copr-source/*.src.rpm "$(outdir)/"
