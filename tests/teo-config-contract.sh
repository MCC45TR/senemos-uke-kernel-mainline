#!/usr/bin/env bash
# Host-only ARM64 Kconfig comparison; no governor or platform-state writes.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_tree=$(realpath -- "${1:?Prepared Linux source directory required}")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/baseline" "$work/candidate"
cp "$root/packaging/native/native.config" "$work/baseline/.config"
make -s -C "$source_tree" ARCH=arm64 LLVM=1 O="$work/baseline" olddefconfig
diff -u "$root/packaging/native/native.config" "$work/baseline/.config"
grep -Fx CONFIG_CPU_IDLE_GOV_MENU=y "$work/baseline/.config"
grep -Fx '# CONFIG_CPU_IDLE_GOV_TEO is not set' "$work/baseline/.config"
(cd "$work"; KCONFIG_CONFIG="$work/candidate/.config" \
    bash "$source_tree/scripts/kconfig/merge_config.sh" -m \
    "$work/baseline/.config" "$root/configs/experiments/teo.config")
make -s -C "$source_tree" ARCH=arm64 LLVM=1 O="$work/candidate" olddefconfig
for variant in baseline candidate; do
    awk '/^CONFIG_[A-Z0-9_]+=/ {print;next}
         /^# CONFIG_[A-Z0-9_]+ is not set$/ {print $2"=n"}' \
        "$work/$variant/.config" | LC_ALL=C sort > "$work/$variant.values"
    grep -v '^CONFIG_CPU_IDLE_GOV_TEO=' "$work/$variant.values" > "$work/$variant.unrelated"
done
diff -u "$work/baseline.unrelated" "$work/candidate.unrelated"
grep -Fx CONFIG_CPU_IDLE_GOV_MENU=y "$work/candidate/.config"
grep -Fx CONFIG_CPU_IDLE_GOV_TEO=y "$work/candidate/.config"
diff -u --label baseline --label teo "$work/baseline.values" "$work/candidate.values" || [[ $? == 1 ]]
printf 'ARM64 optional TEO with MENU and every unrelated option retained: PASS\n'
