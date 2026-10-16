#!/usr/bin/env bash
# Verify optional tracing and unchanged pre-existing device configuration.
set -Eeuo pipefail
config=${1:?Pass normalized development config}
baseline=${2:?Pass preceding normalized config}
fragment=${3:-configs/development-debug.config}
while IFS= read -r option; do
    [[ $option == CONFIG_*=y ]] || continue
    grep -Fxq "$option" "$config" || { printf 'Missing debug option: %s\n' "$option" >&2; exit 1; }
done < "$fragment"
# These are the only pre-existing enabled values changed by tracing selection.
awk '
    FNR == NR {
        if ($0 ~ /^CONFIG_[A-Z0-9_]+=/) {split($0, a, "="); old[a[1]]=$0}
        next
    }
    /^CONFIG_[A-Z0-9_]+=/ {split($0, a, "="); current[a[1]]=$0}
    END {
        for (name in old) {
            if (name == "CONFIG_INITRAMFS_SOURCE" || name == "CONFIG_FUNCTION_ALIGNMENT") continue
            if (current[name] != old[name]) {print "Changed baseline option: " old[name] " -> " current[name] > "/dev/stderr"; failed=1}
        }
        exit failed
    }
' "$baseline" "$config"
for option in KASAN PROVE_LOCKING FAULT_INJECTION FTRACE_STARTUP_TEST BOOTTIME_TRACING; do
    if grep -Eq "^CONFIG_${option}=[ym]$" "$config"; then
        printf 'Unrequested automatic/invasive debug mode: %s\n' "$option" >&2
        exit 1
    fi
done
printf 'Development tracing options and preceding enabled device settings: passed\n'
