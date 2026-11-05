#!/usr/bin/env bash
# COPR only: original allocator control, real callbacks and required mutants.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
kernel=$(realpath -- "${1:?Prepared cumulative kernel}")
smmu=$kernel/drivers/iommu/arm/arm-smmu
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
ulimit -c 0
expect_assertion() {
    local result
    if "$@" > "$stage/refusal.log" 2>&1; then
        printf 'Required original/mutant control unexpectedly passed\n' >&2
        exit 1
    else result=$?; fi
    if [[ $result != 134 ]]; then
        cat "$stage/refusal.log" >&2
        printf 'Control failed outside its required assertion: %s\n' "$result" >&2
        exit 1
    fi
    printf 'Required assertion control refused with134\n'
}
expect_assertion env CC=gcc bash "$owner/tests/cdsp-actlr-contract.sh" \
    "$smmu" "$owner/src/cdsp/uke-cdsp-smmu.c"
bash "$owner/src/cdsp/apply-actlr.sh" "$kernel"
for compiler in gcc clang; do
    CC=$compiler CFLAGS= bash "$owner/tests/cdsp-actlr-contract.sh" "$smmu"
    CC=$compiler CFLAGS='-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer' \
        bash "$owner/tests/cdsp-actlr-contract.sh" "$smmu"
    CC=$compiler bash "$owner/tests/iris-smmu-contract.sh" "$smmu"
done
for mutation in value readback boot-bank masked-rule; do
    case "$mutation" in
        value) expression='s/ARM_SMMU_CB_ACTLR, 0x303)/ARM_SMMU_CB_ACTLR, 0x103)/';;
        readback) expression='s/if (value != 0x303)/if (value != 0x303 \&\& false)/';;
        boot-bank) expression='s/ || test_bit(cb, smmu->boot_context_map)//';;
        masked-rule) expression='s/id != sid || mask || value/id != sid || value/';;
    esac
    sed "$expression" "$smmu/uke-cdsp-smmu.c" > "$stage/$mutation.c"
    ! cmp -s "$smmu/uke-cdsp-smmu.c" "$stage/$mutation.c"
    expect_assertion env CC=gcc bash "$owner/tests/cdsp-actlr-contract.sh" "$smmu" "$stage/$mutation.c"
    printf 'Required mutant refused: %s\n' "$mutation"
done
printf 'Prepared CDSP SMMU source identities:\n'
sha256sum "$smmu/arm-smmu-qcom.c" "$smmu/uke-cdsp-smmu.c"
printf 'Actual CDSP/retained-video callbacks qualify; physical DMA and computation remain separate gates\n'
