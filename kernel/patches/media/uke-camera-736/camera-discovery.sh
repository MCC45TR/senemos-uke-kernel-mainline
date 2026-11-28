#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# -ge 2 ]]
action=$1
tree=$(realpath -e -- "$2")
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
groups=(identify receiver cci/boot identify/rear receiver/boot receiver/media-abi)
scripts=(prepare-paged-id.sh prepare-camera-receiver.sh prepare-cci0-boot.sh prepare-rear-identity.sh prepare-camss-boot.sh prepare-camss-media-abi.sh)
cd "$tree"

case "$action" in
    run)
        [[ $# -ge 4 ]]
        out=$3
        shift 3
        bash "$assets/camera-discovery.sh" prepare "$tree"
        restore_after_build() {
            local status=$?
            trap - EXIT
            bash "$assets/camera-discovery.sh" restore "$tree" || status=44
            exit "$status"
        }
        trap restore_after_build EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        "$@"
        bash "$assets/camera-discovery.sh" verify "$tree" "$out"
        ;;
    prepare)
        [[ $# == 2 ]]
        (cd "$assets"; sha256sum -c --strict SHA256SUMS)
        for group in "${groups[@]:0:3}"; do
            sha256sum -c --strict "$assets/$group/before.sha256"
        done
        applied=0
        rollback() {
            local status=$?
            trap - EXIT
            if ((status)); then
                while ((applied)); do
                    applied=$((applied - 1))
                    bash "$assets/${groups[applied]}/${scripts[applied]}" restore "$tree" || status=44
                done
            fi
            exit "$status"
        }
        trap rollback EXIT
        for index in "${!groups[@]}"; do
            bash "$assets/${groups[index]}/${scripts[index]}" prepare "$tree"
            applied=$((applied + 1))
        done
        ;;
    verify)
        [[ $# == 3 ]]
        out=$(realpath -e -- "$3")
        sha256sum -c --strict "$assets/final-source.sha256"
        [[ ! -e drivers/media/i2c/uke-front-camera-clock.h ]]
        grep -Fx 'obj-$(CONFIG_SM_CAMCC_7675) += uke-rear-camera-id.o' drivers/media/i2c/Makefile
        grep -Fx CONFIG_I2C_QCOM_CCI=m "$out/.config"
        grep -Fx CONFIG_VIDEO_QCOM_CAMSS=y "$out/.config"
        grep -Fx CONFIG_SM_CAMCC_7675=y "$out/.config"
        objects=(
            arch/arm64/kernel/uke-abl.o
            drivers/media/i2c/uke-front-camera-id.o
            drivers/interconnect/qcom/qnoc-cliffs-usb.o
            drivers/iommu/arm/arm-smmu/arm-smmu-qcom.o
            drivers/regulator/qcom-rpmh-regulator-uke.o
            drivers/i2c/busses/i2c-qcom-cci.o
            drivers/media/i2c/uke-rear-camera-id.o
            drivers/media/platform/qcom/camss/camss.o
        )
        result=$out/uke-camera-discovery
        mkdir -p "$result"
        for object in "${objects[@]}"; do
            llvm-readelf -h "$out/$object" | grep -E 'Machine:[[:space:]]+AArch64'
        done
        strings "$out/${objects[0]}" > "$result/boot-strings"
        grep -Fx 'qcom,sm7675-cci' "$result/boot-strings"
        grep -Fx 'uke-front-camera-identify' "$result/boot-strings"
        grep -Fx 'xiaomi,uke-rear-camera-identify' "$result/boot-strings"
        grep -Fx 'qcom,sm7675-camss' "$result/boot-strings"
        llvm-nm "$out/${objects[1]}" > "$result/front-symbols"
        grep -E ' [tT] paged_sensor_id_show$' "$result/front-symbols"
        llvm-nm "$out/${objects[2]}" > "$result/icc-symbols"
        grep -E ' [bdrt] qhs_camera_cfg$' "$result/icc-symbols"
        llvm-nm "$out/${objects[3]}" > "$result/smmu-symbols"
        grep -E ' [bdrt] qcom_uke_camss_init_context$' "$result/smmu-symbols"
        strings "$out/${objects[4]}" > "$result/rpmh-strings"
        grep -Fx 'regulator-pmr735a-l6' "$result/rpmh-strings"
        grep -Fx 'regulator-pmxr2230-l14' "$result/rpmh-strings"
        llvm-nm "$out/${objects[5]}" > "$result/cci-symbols"
        grep -E ' [tT] cci_probe$' "$result/cci-symbols"
        grep -E ' [tT] cci_remove$' "$result/cci-symbols"
        (cd "$out"; sha256sum "${objects[@]}") > "$result/objects.sha256"
        llvm-nm "$out/${objects[6]}" > "$result/rear-symbols"
        grep -E ' [tT] (sensor_id_show|model_id_show)$' "$result/rear-symbols"
        [[ $(grep -Ec ' [tT] (sensor_id_show|model_id_show)$' "$result/rear-symbols") == 2 ]]
        strings "$out/${objects[7]}" > "$result/camss-strings"
        grep -Fx 'qcom,sm7675-camss' "$result/camss-strings"
        grep -Fx 'qcom-camss' "$result/camss-strings"
        install -m644 "$assets/final-source.sha256" "$result/source.sha256"
        ;;
    restore)
        [[ $# == 2 ]]
        for ((index=${#groups[@]} - 1; index >= 0; index--)); do
            bash "$assets/${groups[index]}/${scripts[index]}" restore "$tree"
        done
        ;;
    *) exit 64 ;;
esac
