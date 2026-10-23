#!/usr/bin/env bash
# Host-only ARM64 Kconfig comparison; pass the prepared project Linux source.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_tree=$(realpath -- "${1:?Prepared Linux source directory required}")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/baseline" "$work/candidate"
cp "$root/packaging/native/native.config" "$work/baseline/.config"
make -s -C "$source_tree" ARCH=arm64 LLVM=1 O="$work/baseline" olddefconfig
diff -u "$root/packaging/native/native.config" "$work/baseline/.config"
grep -Fx '# CONFIG_LRU_GEN is not set' "$work/baseline/.config"
(cd "$work"; KCONFIG_CONFIG="$work/candidate/.config" \
    bash "$source_tree/scripts/kconfig/merge_config.sh" -m \
    "$work/baseline/.config" "$root/configs/experiments/mglru.config")
make -s -C "$source_tree" ARCH=arm64 LLVM=1 O="$work/candidate" olddefconfig
for option in CONFIG_LRU_GEN=y CONFIG_LRU_GEN_WALKS_MMU=y \
    '# CONFIG_LRU_GEN_ENABLED is not set' '# CONFIG_LRU_GEN_STATS is not set'; do
    grep -Fx "$option" "$work/candidate/.config"
done
for variant in baseline candidate; do
    awk '/^CONFIG_[A-Z0-9_]+=/ {print;next}
         /^# CONFIG_[A-Z0-9_]+ is not set$/ {print $2"=n"}' \
        "$work/$variant/.config" | LC_ALL=C sort > "$work/$variant.values"
    grep -v -E '^CONFIG_LRU_GEN(_ENABLED|_STATS|_WALKS_MMU)?=' \
        "$work/$variant.values" > "$work/$variant.unrelated"
done
diff -u "$work/baseline.unrelated" "$work/candidate.unrelated"
diff -u "$work/baseline.values" "$work/candidate.values" || [[ $? == 1 ]]
printf 'ARM64 MGLRU default-off configuration and unchanged non-MGLRU options: PASS\n'
