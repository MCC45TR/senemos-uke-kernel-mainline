#!/usr/bin/env bash
# Host-only ARM64 Kconfig comparison; no module or swap activation.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_tree=$(realpath -- "${1:?Prepared Linux source directory required}")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/baseline" "$work/candidate"
cp "$root/packaging/native/native.config" "$work/baseline/.config"
make -s -C "$source_tree" ARCH=arm64 LLVM=1 O="$work/baseline" olddefconfig
for option in CONFIG_SWAP=y CONFIG_PSI=y '# CONFIG_ZRAM is not set' \
    '# CONFIG_ZSWAP is not set' '# CONFIG_LRU_GEN is not set'; do
    grep -Fx "$option" "$work/baseline/.config"
done
(cd "$work"; KCONFIG_CONFIG="$work/candidate/.config" \
    bash "$source_tree/scripts/kconfig/merge_config.sh" -m \
    "$work/baseline/.config" "$root/configs/experiments/zram.config")
make -s -C "$source_tree" ARCH=arm64 LLVM=1 O="$work/candidate" olddefconfig
for variant in baseline candidate; do
    awk '/^CONFIG_[A-Z0-9_]+=/ {print;next}
         /^# CONFIG_[A-Z0-9_]+ is not set$/ {print $2"=n"}' \
        "$work/$variant/.config" | LC_ALL=C sort > "$work/$variant.values"
    grep -v -E '^CONFIG_(ZRAM|ZSMALLOC)(_[A-Z0-9_]+)?=' \
        "$work/$variant.values" > "$work/$variant.unrelated"
done
diff -u "$work/baseline.unrelated" "$work/candidate.unrelated"
for option in CONFIG_ZRAM=m CONFIG_ZSMALLOC=m CONFIG_ZRAM_BACKEND_LZ4=y \
    CONFIG_ZRAM_BACKEND_ZSTD=y CONFIG_ZRAM_DEF_COMP_LZ4=y 'CONFIG_ZRAM_DEF_COMP="lz4"' \
    '# CONFIG_ZRAM_WRITEBACK is not set' '# CONFIG_ZRAM_MULTI_COMP is not set' \
    '# CONFIG_ZRAM_MEMORY_TRACKING is not set' '# CONFIG_ZRAM_TRACK_ENTRY_ACTIME is not set'; do
    grep -Fx "$option" "$work/candidate/.config"
done
diff -u --label baseline --label zram "$work/baseline.values" "$work/candidate.values" || [[ $? == 1 ]]
printf 'ARM64 optional zram module/backends and unchanged non-zram options: PASS\n'
