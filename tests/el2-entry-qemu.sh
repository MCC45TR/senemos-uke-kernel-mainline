#!/usr/bin/env bash
# Generic ARM64 TCG tests, including real rejection of an unsupported vendor SMC.
set -Eeuo pipefail
[[ $# == 2 && ( $1 == build || $1 == run ) ]] || exit 64
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
out=$(realpath -m "$2")
if [[ $1 == build ]]; then
    [[ ! -e $out ]] || exit 64
    mkdir -p "$out"
    cat > "$out/link.ld" <<'LD'
ENTRY(_start)
SECTIONS { . = 0x40080000; .text : { *(.text) *(.idmap.text) } }
LD
    for test in el2 el1 exit-el2 exit-el1 exit-return-el1 args cache-el1 cache-el2 stage2 secondary-el2 secondary-el1; do
        flags=(-DUKE_EL2_TEST=1 -DEXPECTED_REASON=0)
        case $test in
            el1) flags+=(-UEXPECTED_REASON -DEXPECTED_REASON=1) ;;
            exit-return-el1) flags+=(-DUKE_EL2_TEST_RETURN=1 -DCONFIG_QCOM_UKE_GUNYAH_EXIT=1 -UEXPECTED_REASON -DEXPECTED_REASON=4) ;;
            exit-*) flags+=(-DCONFIG_QCOM_UKE_GUNYAH_EXIT=1 -UEXPECTED_REASON -DEXPECTED_REASON=4) ;;
            args) flags+=(-DCONFIG_QCOM_UKE_GUNYAH_EXIT=1 -DBAD_ARGS -UEXPECTED_REASON -DEXPECTED_REASON=2) ;;
            cache-*) flags+=(-DCONFIG_QCOM_UKE_GUNYAH_EXIT=1 -DBAD_CACHE -UEXPECTED_REASON -DEXPECTED_REASON=3) ;;
            stage2) flags+=(-DBAD_STAGE2 -UEXPECTED_REASON -DEXPECTED_REASON=5) ;;
            secondary-*) flags+=(-DSECONDARY -UEXPECTED_REASON -DEXPECTED_REASON=6) ;;
        esac
        clang --target=aarch64-linux-gnu -c "${flags[@]}" "$root/src/boot/uke-el2-entry.S" -o "$out/$test-entry.o"
        clang --target=aarch64-linux-gnu -c "${flags[@]}" "$root/tests/el2-entry-harness.S" -o "$out/$test-harness.o"
        ld.lld -T "$out/link.ld" "$out/$test-harness.o" "$out/$test-entry.o" -o "$out/$test.elf"
    done
    # The production object must contain no semihosting or test-hook reference.
    clang --target=aarch64-linux-gnu -DCONFIG_QCOM_UKE_GUNYAH_EXIT=1 -c "$root/src/boot/uke-el2-entry.S" -o "$out/production.o"
    if llvm-nm -u "$out/production.o" | grep .; then exit 1; fi
    llvm-objdump -d "$out/production.o" > "$out/production.disassembly"
    if grep -E '\bhlt\b|uke_el2_test' "$out/production.disassembly"; then exit 1; fi
    grep -E '\bsmc\b' "$out/production.disassembly" >/dev/null
    (cd "$out"; sha256sum ./*.elf production.o > SHA256SUMS)
    exit
fi
(cd "$out"; sha256sum -c SHA256SUMS)
for test in el2 el1 exit-el2 exit-el1 exit-return-el1 args cache-el1 cache-el2 stage2 secondary-el2 secondary-el1; do
    virt=on expected=REFUSED
    case $test in el1|exit-el1|exit-return-el1|args|cache-el1|secondary-el1) virt=off ;; esac
    case $test in el2|exit-el2|secondary-el2) expected=PASS ;; esac
    status=0
    timeout --kill-after=2s 8s qemu-system-aarch64 \
        -machine "virt,virtualization=$virt" -accel tcg,thread=single -cpu max \
        -m 128 -smp 1 -display none -monitor none -nic none \
        -serial stdio -semihosting-config enable=on,target=native \
        -kernel "$out/$test.elf" > "$out/$test.log" 2>&1 || status=$?
    grep -Fx UKE_EL2_TEST_STARTED "$out/$test.log" >/dev/null
    if [[ $test == exit-el1 ]]; then
        [[ $status == 124 ]]
        if grep -E 'UKE_EL2_ENTRY_(PASS|REFUSED|FAIL)' "$out/$test.log"; then exit 1; fi
        echo 'Generic QEMU vendor SMC did not return; this is not firmware support'
        continue
    fi
    [[ $status == 0 ]]
    grep -Fx "UKE_EL2_ENTRY_$expected" "$out/$test.log"
    if grep -F UKE_EL2_ENTRY_FAIL "$out/$test.log"; then exit 1; fi
done
printf '{"evidence_class":"generic-arm64-tcg-early-entry","cases":11,"passed":true,"error_return_synthetic":true,"unsupported_smc_did_not_return":true,"uke_firmware_switch_tested":false,"hardware_tested":false}\n' > "$out/result.json"
