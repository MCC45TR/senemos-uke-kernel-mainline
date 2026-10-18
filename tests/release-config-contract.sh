#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
config=${1:-$root/packaging/native/native.config}
for option in F2FS_FS F2FS_FS_XATTR F2FS_FS_POSIX_ACL F2FS_FS_SECURITY EXT4_FS SECURITY_SELINUX CMDLINE_FORCE; do
    grep -Fxq "CONFIG_$option=y" "$config"
done
for option in DEBUG_INFO DEBUG_MISC DEBUG_FS DYNAMIC_DEBUG DYNAMIC_DEBUG_CORE \
    SLUB_DEBUG DEBUG_MEMORY_INIT FTRACE FUNCTION_TRACER KPROBES KASAN KCSAN UBSAN \
    F2FS_CHECK_FS F2FS_FAULT_INJECTION F2FS_STAT_FS F2FS_IOSTAT; do
    if grep -Eq "^CONFIG_$option=[ym]$" "$config"; then
        echo "Release instrumentation enabled: $option" >&2; exit 1
    fi
done
line=$(sed -n 's/^CONFIG_CMDLINE="\(.*\)"$/\1/p' "$config")
[[ $line == *'root=PARTLABEL=linux '* ]]
[[ $line != *senemos.debug* && $line != *rd.debug* && $line != *rootfstype=* && $line != *systemd.unit=* ]]
if grep -Eq 'inst_simple.*(uke-cdc-shell|uke-initrd-screen)|ln -s.*(uke-cdc-shell|uke-initrd-screen)' "$root/src/boot/dracut/module-setup.sh"; then
    echo 'Development root shell entered the release initramfs recipe' >&2; exit 1
fi
echo 'Release root filesystems, security labels, command line and instrumentation policy passed'
