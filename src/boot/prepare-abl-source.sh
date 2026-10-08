#!/usr/bin/env bash
# Host-only preparation on an isolated, already qualified 13-patch source tree.
set -Eeuo pipefail
[[ $# == 2 && -d $1 && -d $2 ]] || exit 2
kernel=$(realpath "$1") output=$(realpath "$2")
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ $(awk '/^VERSION =/ {v=$3} /^PATCHLEVEL =/ {p=$3} /^SUBLEVEL =/ {s=$3} END {print v "." p "." s}' "$kernel/Makefile") == 7.2.9 ]]
[[ $(wc -l < "$kernel/senemos-applied-patches.txt") == 13 ]]
patch --batch --fuzz=0 -p1 -d "$kernel" < "$here/../../patches/boot/0001-arm64-uke-abl-dt-hook.patch"
install -m644 "$here/uke-abl.c" "$kernel/arch/arm64/kernel/uke-abl.c"
[[ $(sha256sum "$here/vendor/fdt_check.c" | cut -d ' ' -f1) == "$(jq -er .sha256 "$here/vendor/source.json")" ]]
grep -F 'DTC 1.7.2-g53373d13' "$kernel/scripts/dtc/version_gen.h" >/dev/null
install -m644 "$here/vendor/fdt_check.c" "$kernel/scripts/dtc/libfdt/fdt_check.c"
for name in overlay check; do
    {
        printf '// SPDX-License-Identifier: GPL-2.0-only\n#include <linux/libfdt_env.h>\n'
        # The embedded, source-compiled overlays contain bounded decimal
        # fixup offsets. Upstream libfdt's libc parser needs the kernel API.
        if [[ $name == overlay ]]; then
            printf '#include <linux/kstrtox.h>\n#define strtoul simple_strtoul\n'
        fi
        printf '#include "../scripts/dtc/libfdt/fdt_%s.c"\n' "$name"
    } > "$kernel/lib/fdt_$name.c"
done
header=$kernel/arch/arm64/kernel/uke-abl-overlays.h
: > "$header"
for name in ufs usb; do
    source=$here/sm7675-uke-ufs.dtso
    [[ $name != usb ]] || source=$here/sm7675-uke-usb2.dtso
    cpp -nostdinc -undef -D__DTS__ -x assembler-with-cpp -I "$kernel/include" "$source" > "$output/$name.dts"
    dtc -q -@ -I dts -O dtb -o "$output/$name.dtbo" "$output/$name.dts"
    {
        printf 'static unsigned char uke_%s_overlay[] __initdata __aligned(8) = {\n' "$name"
        od -An -v -tx1 "$output/$name.dtbo" | sed -E 's/[a-f0-9]{2}/0x&,/g'
        printf '};\n'
    } >> "$header"
done
(cd "$output"; sha256sum ufs.dtbo usb.dtbo > overlay-SHA256SUMS)
sha256sum "$here/uke-abl.c" "$here/vendor/fdt_check.c" "$here/vendor/source.json" \
    "$here/../../patches/boot/0001-arm64-uke-abl-dt-hook.patch" "$header" > "$output/abl-source-SHA256SUMS"
