#!/usr/bin/env bash
# Generic ARM64 TCG only. The nested KVM MMIO guest is real emulated execution.
set -Eeuo pipefail
[[ $# == 4 && -f $1 && -f $2 && -f $3 && ! -e $4 ]] || exit 64
kernel=$(realpath "$1") probe_initrd=$(realpath "$2") guest_initrd=$(realpath "$3")
out=$(realpath -m "$4")
mkdir -p "$out"
for test in el1-probe el2-probe linux-1 linux-2; do
    virt=off cpus=1 arguments='' initrd=$probe_initrd
    [[ $test != el2-probe ]] || virt=on
    case $test in linux-*) cpus=${test#linux-}; arguments="-- $cpus"; initrd=$guest_initrd ;; esac
    timeout --signal=TERM --kill-after=3s 60s qemu-system-aarch64 \
        -machine "virt,gic-version=3,virtualization=$virt" -cpu max -accel tcg,thread=single \
        -m 256 -smp "$cpus" -display none -monitor none -nic none -no-reboot \
        -serial "file:$out/$test.serial.log" -kernel "$kernel" -initrd "$initrd" \
        -append "console=ttyAMA0 rdinit=/init panic=1 $arguments" > "$out/$test.qemu.log" 2>&1
    tr -d '\r' < "$out/$test.serial.log" > "$out/$test.serial.txt"
    case $test in
        el1-probe)
            grep -Fx '{"status":"blocked-no-kvm","guest_ran":false}' "$out/$test.serial.txt"
            grep -Fx 'UKE_KVM_PROBE_INIT_EXIT=2' "$out/$test.serial.txt"
            grep -F 'All CPU(s) started at EL1' "$out/$test.serial.txt" >/dev/null
            ;;
        el2-probe)
            grep -Fx '{"status":"kvm-guest-pass","guest_ran":true,"api_version":12}' "$out/$test.serial.txt"
            grep -Fx 'UKE_KVM_PROBE_INIT_EXIT=0' "$out/$test.serial.txt"
            grep -F 'All CPU(s) started at EL2' "$out/$test.serial.txt" >/dev/null
            ;;
        linux-*)
            grep -Fx "UKE_KVM_LINUX_PASS cpus=$cpus timer=pass migration=pass" "$out/$test.serial.txt"
            if grep -F UKE_KVM_LINUX_FAIL "$out/$test.serial.txt"; then exit 1; fi
            ;;
    esac
done
cat > "$out/result.json" <<JSON
{"schema_version":1,"evidence_class":"generic-arm64-tcg-linux-kvm",
 "kernel_sha256":"$(sha256sum "$kernel" | cut -d ' ' -f1)",
 "probe_initramfs_sha256":"$(sha256sum "$probe_initrd" | cut -d ' ' -f1)",
 "linux_initramfs_sha256":"$(sha256sum "$guest_initrd" | cut -d ' ' -f1)",
 "el1_rejected":true,"emulated_el2_kvm_mmio_guest_ran":true,
 "tcg_linux_one_vcpu":true,"tcg_linux_two_vcpu":true,"timer_and_migration":true,
 "full_linux_under_kvm_tested":false,"uke_el2_boot_tested":false,"hardware_tested":false}
JSON
