#!/usr/bin/env bash
# COPR only: cumulative prepared/linked admission, never physical acceptance.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
output=$(realpath -m "${2:?Native output}")
phase=${3:?prepared or linked}
[[ $phase == prepared || $phase == linked ]]
profile=$kernel/native-profile
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.governor_options_layer==1 and
 .speaker_state_observer_layer_commit=="13fb0ff522531924c0e96f81cef59d7c64b93eb8" and
 .speaker_inclusion_gate_commit=="33a5dc574401b67472e9bea65e5ff7084635f601" and
 .speaker_pre_image_inclusion_required and .speaker_protection_graph_admitted==false and
 .speaker_gain_ceiling==223 and .speaker_physical_protection_qualified==false and
 .pogo_backlight_source=="e9867405d0773065880863ea2df0dbd6242f5894" and
 .ssc_early_sample_layer==2 and .ssc_early_sample_requires_ack and
 .ssc_early_sample_physical_acceptance==false and .camera_gcc_config_layer==1 and
 .camera_gcc_config_check==11263019 and .camera_gcc_config_physical_acceptance==false and
 .front_eeprom_read_only and .front_geni_dt_activation==false and
 .front_eeprom_dt_activation==false and .camera_sensor_dt_activation==false and
 .camera_capture_graph_activation==false and .physical_acceptance==false and
 .automatic_seamless_staging_required and .preserve_local_rollback_preference' \
 "$profile/source-composition.json" >/dev/null
printf '%s  %s\n' f57b6a5aecebc265fdfe25b6f06acae992853f139a3980103c9b86f3870bca7b \
    "$kernel/drivers/clk/qcom/gcc-cliffs.c" | sha256sum -c --strict -
cmp "$profile/src/audio/uke-fs19xx-runtime.c" "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
cmp "$profile/src/sensors/uke-ssc-iio.c" "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c"
for name in hid-nanosic-uke.c nanosic-uke-protocol.h nanosic-uke-hid.h; do
    cmp "$profile/src/pogo/$name" "$kernel/drivers/hid/$name"
done
if [[ $phase == prepared ]]; then
    for compiler in g++ clang++; do
        CXX=$compiler CAMERA_GCC_MUTATIONS=1 bash "$profile/tests/camera-gcc-config731-contract.sh" \
            "$kernel/drivers/clk/qcom/gcc-cliffs.c" "$kernel/native-generated/gcc-before-camera-config.c"
        CXX=$compiler CAMERA_GCC_TEST_FLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
            bash "$profile/tests/camera-gcc-config731-contract.sh" \
            "$kernel/drivers/clk/qcom/gcc-cliffs.c" "$kernel/native-generated/gcc-before-camera-config.c"
    done
    for compiler in gcc clang; do
        for flags in '' '-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'; do
            CC=$compiler CFLAGS=$flags bash "$profile/tests/audio-speaker-state-read-contract.sh" \
                "$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
            for fixture in protocol lifecycle backlight power hid; do
                CC=$compiler CFLAGS=$flags bash "$profile/tests/nanosic-$fixture-contract.sh"
            done
        done
    done
    bash "$profile/tests/ssc-native-contract.sh" "$kernel"
    printf 'Cumulative camera GCC/peer prepared sources and callback gates pass; electrical/fitted cameras remain unqualified\n'
    exit 0
fi
for object in drivers/clk/qcom/gcc-cliffs.o drivers/clk/qcom/camcc-sm7675.o \
    drivers/hid/hid-nanosic-uke.o drivers/iio/common/uke-ssc/uke-ssc.o \
    sound/soc/qcom/qdsp6/uke-fs19xx-runtime.o; do
    test -s "$output/$object"
    llvm-readelf -h "$output/$object" | grep -E 'Machine:.*AArch64'
done
test -s "$output/arch/arm64/boot/Image"
printf 'Cumulative camera GCC and peer objects coexist in production output; no physical camera/calibration/focus acceptance\n'
