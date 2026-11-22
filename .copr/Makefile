SHELL := /bin/bash
repo := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

.PHONY: srpm
srpm:
	dnf -y --setopt=install_weak_deps=False install curl jq gnupg2 rpm-build cpio git-core xz tar coreutils
	bash "$(repo)/packaging/rpm/kernel/build-srpm.sh" "$(outdir)"
