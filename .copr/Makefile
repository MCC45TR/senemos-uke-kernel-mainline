SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: srpm
srpm:
	# COPR runs source generation as root in its isolated Fedora mock chroot.
	dnf -y --setopt=install_weak_deps=False install make curl jq gnupg2 xz tar rpm-build coreutils
	$(MAKE) -f Makefile srpm outdir="$(outdir)"
