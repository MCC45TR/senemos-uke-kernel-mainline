SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.ONESHELL:
.PHONY: validate srpm
version := 7.2.11
outdir ?= $(CURDIR)/build/srpm
validate: validate-video validate-ufs validate-cpucp validate-accessories validate-thermal validate-camera
validate-camera: validate-camcc-data validate-camera-board
	jq -e '.active_config == false and .dt_enabled == false and .camera_capture_tested == false and .kernel_release_changed == false' manifests/camera-source-candidate-20261021.json >/dev/null
	jq -r '.patches[], .source_assets[] | .sha256 + "  " + .path' manifests/camera-source-candidate-20261021.json | sha256sum -c -
	! grep -Eq '^CONFIG_VIDEO_OV(08D10|13B10)=' configs/{arm64-qcom,uke,fedora}.config
.PHONY: validate-camera
validate-camcc-data:
	jq -e '.driver_registered == false and .dt_enabled == false and .tablet_tested == false and .active_config == false and .voltage_clock_count == 44' manifests/camcc-source-candidate-20261021.json >/dev/null
	jq -r '.source_assets[] | .sha256 + "  " + .path' manifests/camcc-source-candidate-20261021.json | sha256sum -c -
	! grep -Eq 'module_platform_driver|platform_driver_register|of_device_id|module_init|subsys_initcall' src/camera/camcc-sm7675-data.h
test-camcc-data: validate-camcc-data
	test -n "$(camcc_source)" && test -n "$(camcc_oem)" && test -n "$(camcc_output)"
	test "$$(realpath "$(camcc_output)")" != "$$(realpath "$(camcc_source)")"
	bash tests/camcc-source-contract.sh "$(camcc_source)" "$(camcc_oem)"
	test -f "$(camcc_output)/include/generated/asm-offsets.h"
	grep -Fx 'CONFIG_ARM64=y' "$(camcc_output)/.config"
	mkdir -p "$(camcc_output)/camcc-contract"
	cp tests/fixtures/camcc-data-check.c "$(camcc_output)/camcc-contract/"
	printf '%s\n' 'obj-m += camcc-data-check.o' 'ccflags-y += -I$(CURDIR)/src/camera -I$(CURDIR)/src/camera/include -I$(camcc_source)/drivers/clk/qcom' > "$(camcc_output)/camcc-contract/Makefile"
	$(MAKE) -C "$(camcc_source)" ARCH=arm64 LLVM=1 O="$(camcc_output)" M="$(camcc_output)/camcc-contract" KCFLAGS=-Werror -j4 camcc-data-check.o
	readelf -h "$(camcc_output)/camcc-contract/camcc-data-check.o" | grep -Eq 'Machine:[[:space:]]+AArch64'
.PHONY: validate-camcc-data test-camcc-data
validate-camera-board:
	jq -e '.active_series == false and .dt_enabled == false and .kernel_release_changed == false and .physical_capture == null and .eeprom_accessed == false' manifests/camera-board-candidate-20261021.json >/dev/null
	jq -r '.source_assets[] | .sha256 + "  " + .path' manifests/camera-board-candidate-20261021.json | sha256sum -c -
	! grep -Fq '0001-dt-bindings-eeprom-camera-64k-models.patch' patches/$(version)/series
test-camera-board: validate-camera-board validate-camcc-data
	test -n "$(camera_source)"
	bash tests/camera-board-contract.sh "$(camera_source)" "$(CURDIR)/src/camera/include"
.PHONY: validate-camera-board test-camera-board
test-camera: validate-camera
	test -n "$(camera_source)" && test -n "$(camera_output)"
	test "$$(realpath -m "$(camera_output)")" = "$(camera_output)"
	test ! -e "$(camera_output)"
	bash tests/camera-source-contract.sh "$(camera_source)"
	cd "$(camera_source)"
	jq -r '.baseline_files[] | .sha256 + "  " + .path' "$(CURDIR)/manifests/camera-source-candidate-20261021.json" | sha256sum -c -
	$(MAKE) ARCH=arm64 LLVM=1 O="$(camera_output)" defconfig
	scripts/kconfig/merge_config.sh -m -O "$(camera_output)" "$(camera_output)/.config" "$(CURDIR)/src/camera/sensors.config"
	$(MAKE) ARCH=arm64 LLVM=1 O="$(camera_output)" olddefconfig
	$(MAKE) ARCH=arm64 LLVM=1 O="$(camera_output)" -j4 modules_prepare
	grep -Fx 'CONFIG_VIDEO_OV08D10=m' "$(camera_output)/.config"
	grep -Fx 'CONFIG_VIDEO_OV13B10=m' "$(camera_output)/.config"
	mkdir -p "$(camera_output)/sensor-source/drivers/media/i2c"
	cp drivers/media/i2c/{ov08d10,ov13b10}.c "$(camera_output)/sensor-source/drivers/media/i2c/"
	cp MAINTAINERS "$(camera_output)/sensor-source/"
	git -C "$(camera_output)/sensor-source" init -q
	for patch in "$(CURDIR)"/src/camera/*.patch; do
		git -C "$(camera_output)/sensor-source" apply --check "$$patch"
		git -C "$(camera_output)/sensor-source" apply "$$patch"
	done
	printf '%s\n' 'obj-m += ov08d10.o ov13b10.o' > "$(camera_output)/sensor-source/drivers/media/i2c/Makefile"
	$(MAKE) ARCH=arm64 LLVM=1 O="$(camera_output)" M="$(camera_output)/sensor-source/drivers/media/i2c" KCFLAGS=-Werror -j4 ov08d10.o ov13b10.o
	for sensor in ov08d10 ov13b10; do
		readelf -h "$(camera_output)/sensor-source/drivers/media/i2c/$$sensor.o" | grep -Eq 'Machine:[[:space:]]+AArch64'
		readelf --wide -s "$(camera_output)/sensor-source/drivers/media/i2c/$$sensor.o" | grep -F "__mod_device_table__kmod_$${sensor}__of__$${sensor}_of_match"
	done
	readelf --wide -s "$(camera_output)/sensor-source/drivers/media/i2c/ov13b10.o" | grep -F '__mod_device_table__kmod_ov13b10__acpi__ov13b10_acpi_ids'
.PHONY: test-camera
validate-thermal:
	jq -e '.active_series == false and .dt_enabled == false and .thermal_policy_changed == false and .calibration_changed == false and .tablet_tested == false and (.patches | length == 1)' manifests/thermal-source-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
		if grep -Fqx "$${path##*/}" patches/$(version)/series; then exit 1; else test "$$?" -eq 1; fi
	done < <(jq -r '.patches[] | [.path,.sha256] | @tsv' manifests/thermal-source-candidate-20261020.json)
.PHONY: validate-thermal test-thermal
test-thermal: validate-thermal
	test -n "$(thermal_source)"
	bash tests/tsens-pm-fault-contract.sh "$(thermal_source)/drivers/thermal/qcom/tsens.c"
validate-accessories:
	jq -e '.active_series == false and .dt_enabled == false and .compatibility_alias_added == false and .nfc_driver_added == false and (.patches | length == 1)' manifests/accessory-source-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
		if grep -Fqx "$${path##*/}" patches/$(version)/series; then exit 1; else test "$$?" -eq 1; fi
	done < <(jq -r '.patches[] | [.path,.sha256] | @tsv' manifests/accessory-source-candidate-20261020.json)
.PHONY: validate-accessories test-accessories
test-accessories: validate-accessories
	test -n "$(accessory_source)"
	bash tests/ir-spi-admission-contract.sh "$(accessory_source)/drivers/media/rc/ir-spi.c"
validate-cpucp:
	jq -e '.active_series == false and .protocol_registered == false and .consumer_added == false and .state_changing_messages == false and (.patches | length == 1)' manifests/cpucp-read-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
		if grep -Fqx "$${path##*/}" patches/$(version)/series; then exit 1; else test "$$?" -eq 1; fi
	done < <(jq -r '.patches[] | [.path,.sha256] | @tsv' manifests/cpucp-read-candidate-20261020.json)
	jq -r '.source_assets[] | .sha256 + "  " + .path' manifests/cpucp-read-candidate-20261020.json | sha256sum -c -
.PHONY: validate-cpucp test-cpucp
test-cpucp: validate-cpucp
	test -n "$(cpucp_source)"
	bash tests/cpucp-memlat-read-contract.sh "$(cpucp_source)/drivers/firmware/arm_scmi/vendors/qcom/qcom-memlat.c" "$(cpucp_source)/include/linux/scmi_qcom_memlat.h" "$(cpucp_source)/drivers/firmware/arm_scmi/shmem.c"
validate-ufs:
	jq -e '.active_series == false and .dt_enabled == false and .tablet_tested == false and .crypto_enabled == false and (.patches | length == 6)' manifests/ufs-source-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
		if grep -Fqx "$${path##*/}" patches/$(version)/series; then exit 1; else test "$$?" -eq 1; fi
	done < <(jq -r '.patches[] | [.path,.sha256] | @tsv' manifests/ufs-source-candidate-20261020.json)
.PHONY: validate-ufs test-ufs
test-ufs: validate-ufs
	test -n "$(ufs_source)"
	bash tests/ufs-mcq-resource-contract.sh "$(ufs_source)"
	bash tests/ice-resume-fault-contract.sh "$(ufs_source)"
	bash tests/ice-mapping-size-contract.sh "$(ufs_source)"
	bash tests/ice-bist-status-contract.sh "$(ufs_source)"
	bash tests/ufs-hce-error-contract.sh "$(ufs_source)"
validate-video:
	jq -e '.active_series == false and .dt_enabled == false and .iris_match_added == false and (.patches | length == 19)' manifests/iris-source-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
		if grep -Fqx "$${path##*/}" patches/$(version)/series; then exit 1; else test "$$?" -eq 1; fi
	done < <(jq -r '.patches[] | [.path,.sha256] | @tsv' manifests/iris-source-candidate-20261020.json)
	jq -r '.source_assets[] | .sha256 + "  " + .path' manifests/iris-source-candidate-20261020.json | sha256sum -c -
.PHONY: validate-video test-video
test-video: validate-video
	test -n "$(video_source)"
	bash tests/iris-2p-lifecycle-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-boot-status-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-resource-fault-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-power-domain-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-firmware-ownership-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-fw-mmap-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-split-dma-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-irq-lifetime-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-power-ownership-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-video-publication-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-format-allocation-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-response-lifetime-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-session-result-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/iris-buffer-return-contract.sh "$(video_source)/drivers/media/platform/qcom/iris"
	bash tests/videocc-vote-contract.sh src/video/uke-videocc-votes.c
validate:
	test "$(version)" = 7.2.11
	jq -e '.version == "$(version)" and .hardware_tested == false and (.patches | length == 97) and (.configs | length == 3)' manifests/linux-$(version).json >/dev/null
	cmp <(jq -r '.patches[].path | split("/") | last' manifests/linux-$(version).json) patches/$(version)/series
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
	done < <(jq -r '.patches[], .configs[] | [.path,.sha256] | @tsv' manifests/linux-$(version).json)
	jq -e '.active_series == true and .dt_enabled == true and .tablet_tested == false and .kernel_release_changed == true and .kernel_release == "7.2.11-17" and (.patches | length == 3)' manifests/llcc-source-candidate-20261020.json >/dev/null
	while IFS=$$'\t' read -r path expected; do
		test "$$(sha256sum "$$path" | cut -d ' ' -f1)" = "$$expected"
	done < <(jq -r '.patches[], .files[] | [.path,.sha256] | @tsv' manifests/llcc-source-candidate-20261020.json)
	bash -n src/boot/prepare-abl-source.sh src/performance/prepare-llcc-dt.sh tests/llcc-sm7675-contract.sh tests/llcc-sm7675-dt-contract.sh tests/llcc-gpu-startup-contract.sh tests/llcc-boot-fdt-contract.sh
	bash tests/mainline-package-contract.sh
	bash tests/firmware-source-package-contract.sh "$(CURDIR)" "$(version)"
	bash tests/firmware-source-package-rejection.sh "$(CURDIR)" "$(version)"
srpm: validate
	cache="$(CURDIR)/referances/releases"
	top="$$(realpath -m "$(outdir)/rpmbuild")"
	mkdir -p "$$cache" "$$top"/{BUILD,BUILDROOT,RPMS,SRPMS,SOURCES,SPECS}
	for name in linux-$(version).tar.xz linux-$(version).tar.sign; do
		if test ! -s "$$cache/$$name"; then
			curl -fL --retry 3 --connect-timeout 20 "https://cdn.kernel.org/pub/linux/kernel/v7.x/$$name" -o "$$cache/$$name.part"
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
	git archive HEAD src/display src/boot src/usb src/audio patches/$(version) patches/display patches/boot tests | tar -xf - -C "$$assets"
	git archive HEAD src/video src/cpucp patches/video patches/ufs patches/cpucp patches/accessories patches/thermal manifests/iris-source-candidate-20261020.json manifests/ufs-source-candidate-20261020.json manifests/cpucp-read-candidate-20261020.json manifests/accessory-source-candidate-20261020.json manifests/thermal-source-candidate-20261020.json | tar -xf - -C "$$assets"
	bash tests/firmware-source-package-contract.sh "$$assets" "$(version)"
	install -m644 packaging/native/native.config packaging/native/README.md packaging/native/usb-profile packaging/native/audio-profile packaging/native/llcc-profile "$$assets/"
	install -m755 packaging/native/prepare.sh "$$assets/"
	git rev-parse HEAD > "$$assets/source-commit"
	(cd "$$assets"; find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
	tar --sort=name --mtime=@$$(jq -er .source_date_epoch manifests/linux-$(version).json) --owner=0 --group=0 --numeric-owner -cJf "$$top/SOURCES/senemos-native-profile-$(version).tar.xz" -C "$$(dirname "$$assets")" native-profile
	sed "s/^Version: .*/Version: $(version)/" packaging/senemos-uke-linux-kernel-mainline.spec > "$$top/SPECS/senemos-uke-linux-kernel-mainline.spec"
	# Source generation needs no target compiler or installed binary BuildRequires.
	bash scripts/stage-boot-sources.sh "$$top/SOURCES"
	rpmbuild -bs --nodeps --target aarch64 --define "_topdir $$top" "$$top/SPECS/senemos-uke-linux-kernel-mainline.spec"
	cp "$$top/SRPMS/"*.src.rpm "$(outdir)/"
# A standalone source clone also owns its host build entry and pinned rules.
.PHONY: test-entry
test-entry:
	./senemos.sh --self-test
