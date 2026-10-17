SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: srpm
outdir ?= $(CURDIR)/../../build/native-copr-source
srpm:
	root="$$(realpath ../..)"
	# COPR source generation runs as root; local dependencies remain explicit.
	if test "$$(id -u)" = 0; then
		dnf -y --setopt=install_weak_deps=False install make curl jq gnupg2 xz tar rpm-build coreutils git-core
	fi
	$(MAKE) -C "$$root" srpm outdir="$$root/build/native-copr-base"
	top="$$root/build/native-copr-source/rpmbuild"
	mkdir -p "$$top"/{SOURCES,SPECS,SRPMS,BUILD,BUILDROOT,RPMS}
	cp "$$root/build/native-copr-base/rpmbuild/SOURCES/"* "$$top/SOURCES/"
	assets="$$root/build/native-copr-source/assets/native-profile"
	mkdir -p "$$assets"
	git -C "$$root" archive HEAD src/display src/boot patches/7.2.9 patches/display patches/boot tests | tar -xf - -C "$$assets"
	install -m644 native.config README.md "$$assets/"
	install -m755 prepare.sh "$$assets/"
	printf '%s\n' "$$(git -C "$$root" rev-parse HEAD)" > "$$assets/source-commit"
	(cd "$$assets"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
	tar --sort=name --mtime=@1791024250 --owner=0 --group=0 --numeric-owner -cJf "$$top/SOURCES/senemos-native-profile-7.2.9.tar.xz" -C "$$(dirname "$$assets")" native-profile
	install -m644 senemos-uke-linux-kernel-mainline-native.spec "$$top/SPECS/"
	rpmbuild -bs --nodeps --target aarch64 --define "_topdir $$top" "$$top/SPECS/senemos-uke-linux-kernel-mainline-native.spec"
	mkdir -p "$(outdir)"
	install -m644 "$$top/SRPMS/"*.src.rpm "$(outdir)/"
