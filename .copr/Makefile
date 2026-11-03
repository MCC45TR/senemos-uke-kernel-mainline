SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: srpm
srpm:
	# This manual experiment must remain an Actions artifact only.
	if test -f manifests/el2-query-20261103.json; then
		echo 'EL2 query candidate: use GitHub Actions; COPR publication is disabled.' >&2
		exit 78
	fi
	# COPR runs source generation as root in its isolated Fedora mock chroot.
	dnf -y --setopt=install_weak_deps=False install make curl jq gnupg2 xz tar rpm-build coreutils git-core gcc gcc-c++
	# COPR collects this directory as an unprivileged user. Keep verification
	# state and the private-mode GPG home in the source workspace, not outdir.
	$(MAKE) -f Makefile srpm outdir="$(CURDIR)/build/copr-source"
	mkdir -p "$(outdir)"
	install -m644 build/copr-source/*.src.rpm "$(outdir)/"
