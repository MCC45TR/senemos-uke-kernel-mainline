SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: srpm
outdir ?= $(CURDIR)/../../build/mainline-copr-source
srpm:
	root="$$(realpath ../..)"
	# Compatibility SCM entry: all kernel outputs now use the mainline name.
	if test "$$(id -u)" = 0; then
		dnf -y --setopt=install_weak_deps=False install make curl jq gnupg2 xz tar rpm-build coreutils git-core
	fi
	$(MAKE) -C "$$root" srpm outdir="$(abspath $(outdir))"
