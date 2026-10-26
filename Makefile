SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: validate srpm test-touch-protocol test-touch-transport test-touch-dt
version := 7.3.0
outdir ?= $(CURDIR)/build/srpm
validate: test-touch-protocol test-touch-transport
	bash -n tests/dp-dsc-contract.sh tests/dp-dsc-state-contract.sh
	bash -n tests/dp-fec-status-contract.sh tests/dp-dsc-tu-contract.sh
	bash -n tests/lid-wake-contract.sh
	bash -n tests/dp-eld-notification-contract.sh
	bash -n tests/dpu-output-affinity-contract.sh tests/ucsi-debugfs-bounds-contract.sh tests/dpu-mixer-reservation-contract.sh
	bash -n src/leds/prepare-source.sh tests/rgb-policy.sh tests/rgb-lifetime.sh tests/rgb-sysfs.sh tests/rgb-syntax.sh
	bash -n src/video/prepare-source.sh tests/iris-sm7675-caps-contract.sh tests/iris-sm7675-schema-contract.sh
	bash tests/rgb-policy.sh
	bash tests/rgb-supplier.sh
	bash -n tests/light-cleanup.sh tests/light-dt.sh tests/light-brightness.sh
	bash tests/uke-build-scope-contract.sh
	bash -n src/boot/check-root-capability.sh tests/root-selector-note-contract.sh
	test "$(version)" = 7.3.0
	jq -e '.version == "$(version)" and .hardware_tested == false and (.patches | length == 115) and (.configs | length == 3)' manifests/linux-$(version).json >/dev/null
	cmp <(jq -r '.patches[].path | split("/") | last' manifests/linux-$(version).json) patches/$(version)/series
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
	done < <(jq -r '.patches[], .configs[] | [.path,.sha256] | @tsv' manifests/linux-$(version).json)
	abi="$$(rpmspec --target aarch64 --define 'dist %{nil}' -q --srpm --qf '%{VERSION}-%{RELEASE}' packaging/senemos-uke-linux-kernel-mainline.spec)"
	jq -e --arg abi "$$abi" '.active_series == true and .dt_enabled == true and .tablet_tested == false and .kernel_release_changed == true and .kernel_release == $$abi and (.patches | length == 3)' manifests/llcc-source-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
	done < <(jq -r '.patches[], .files[] | [.path,.sha256] | @tsv' manifests/llcc-source-candidate-20261020.json)
	bash -n src/boot/prepare-abl-source.sh src/performance/prepare-llcc-dt.sh tests/llcc-sm7675-contract.sh tests/llcc-sm7675-dt-contract.sh tests/llcc-gpu-startup-contract.sh tests/llcc-boot-fdt-contract.sh
	bash tests/mainline-package-contract.sh
	bash tests/mainline-boot-status-contract.sh
	bash tests/upstream-candidate-contract.sh
	bash tests/touch-runtime-package-contract.sh
	bash tests/identity-contract.sh
	bash tests/kernel-family-contract.sh
	bash tests/userdata-grow-contract.sh
	bash tests/early-modules-contract.sh
	bash tests/platform-profile-contract.sh
	bash tests/dispcc-dp-votes-contract.sh src/display/uke-dispcc-votes.c
	bash tests/module-compress-contract.sh
	bash -n tests/resin-wake-contract.sh
	bash -n tests/gpu-fault-capture-contract.sh
test-touch-protocol:
	bash tests/touch-protocol-contract.sh
test-touch-transport:
	bash tests/touch-transport-contract.sh
test-touch-dt:
	test -n "$(kernel_source)" -a -n "$(running_fdt)" -a -n "$(dt_output)"
	bash tests/touch-dt-contract.sh "$(kernel_source)" "$(running_fdt)" "$(dt_output)"
.PHONY: test-root-capability
test-root-capability:
	test -n "$(kernel_source)"
	bash tests/root-selector-note-contract.sh "$(kernel_source)" manifests/boot-payload.json
srpm: validate
	cache="$(CURDIR)/referances/releases"
	top="$$(realpath -m "$(outdir)/rpmbuild")"
	mkdir -p "$$cache" "$$top"/{BUILD,BUILDROOT,RPMS,SRPMS,SOURCES,SPECS}
	for name in linux-$(version).tar.xz linux-$(version).tar.sign; do
		if test ! -s "$$cache/$$name"; then
			url=$$(jq -er --arg n "$$name" 'if ($$n|endswith(".tar.sign")) then .signature_url else .source_url end' manifests/linux-$(version).json)
			curl -fL --retry 3 --connect-timeout 20 "$$url" -o "$$cache/$$name.part"
			mv "$$cache/$$name.part" "$$cache/$$name"
		fi
	done
	expected=$$(jq -er .source_sha256 manifests/linux-$(version).json)
	test "$$(sha256sum "$$cache/linux-$(version).tar.xz" | cut -d ' ' -f1)" = "$$expected"
	keyring=$$(mktemp -d)
	trap 'gpgconf --homedir "$$keyring" --kill gpg-agent; rm -rf -- "$$keyring"' EXIT
	gpg --batch --homedir "$$keyring" --import configs/keys/linux-stable.asc
	xz -cd "$$cache/linux-$(version).tar.xz" | gpg --batch --homedir "$$keyring" --status-fd=1 --verify "$$cache/linux-$(version).tar.sign" - > "$$top/signature.txt"
	grep -F "[GNUPG:] VALIDSIG $$(jq -er .signer manifests/linux-$(version).json) " "$$top/signature.txt"
	rm -rf "$$top/adaptation"
	mkdir -p "$$top/adaptation/senemos-adaptation"/{patches,configs}
	cp patches/$(version)/* "$$top/adaptation/senemos-adaptation/patches/"
	cp configs/{arm64-qcom,uke,fedora}.config "$$top/adaptation/senemos-adaptation/configs/"
	cp manifests/linux-$(version).json "$$top/adaptation/senemos-adaptation/source-lock.json"
	cp patches/$(version)/README.md "$$top/adaptation/senemos-adaptation/README.md"
	tar --sort=name --mtime=@$$(jq -er .source_date_epoch manifests/linux-$(version).json) --owner=0 --group=0 --numeric-owner -cJf "$$top/SOURCES/senemos-uke-adaptation-$(version).tar.xz" -C "$$top/adaptation" senemos-adaptation
	cp "$$cache/linux-$(version).tar."{xz,sign} configs/keys/linux-stable.asc "$$top/SOURCES/"
	assets="$$(mktemp -d "$$top/profile.XXXXXX")/native-profile"
	mkdir -p "$$assets"
	git archive HEAD src/leds src/video patches/video manifests/video-linux73-candidate-20261025.json src/display src/boot src/usb src/audio src/power src/input patches/$(version) patches/display patches/boot patches/input tests | tar -xf - -C "$$assets"
	install -m644 packaging/native/native.config packaging/native/README.md packaging/native/usb-profile packaging/native/audio-profile packaging/native/llcc-profile "$$assets/"
	install -m755 packaging/native/prepare.sh "$$assets/"
	git rev-parse HEAD > "$$assets/source-commit"
	(cd "$$assets"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
	tar --sort=name --mtime=@$$(jq -er .source_date_epoch manifests/linux-$(version).json) --owner=0 --group=0 --numeric-owner -cJf "$$top/SOURCES/senemos-native-profile-$(version).tar.xz" -C "$$(dirname "$$assets")" native-profile
	sed "s/^Version: .*/Version: $(version)/" packaging/senemos-uke-linux-kernel-mainline.spec > "$$top/SPECS/senemos-uke-linux-kernel-mainline.spec"
	# Source generation needs no target compiler or installed binary BuildRequires.
	bash scripts/stage-boot-sources.sh "$$top/SOURCES"
	bash scripts/stage-touch-runtime.sh "$$top/SOURCES"
	install -m644 packaging/SINGLEBOOT.md "$$top/SOURCES/SINGLEBOOT.md"
	install -m644 LICENSE "$$top/SOURCES/singleboot-LICENSE"
	rpmbuild -bs --nodeps --target aarch64 --define "_topdir $$top" "$$top/SPECS/senemos-uke-linux-kernel-mainline.spec"
	cp "$$top/SRPMS/"*.src.rpm "$(outdir)/"
# A standalone source clone also owns its host build entry and pinned rules.
.PHONY: test-entry
test-entry:
	./senemos.sh --self-test
