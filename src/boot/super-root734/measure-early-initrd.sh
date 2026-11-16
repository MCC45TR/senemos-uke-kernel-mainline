#!/usr/bin/bash
# COPR only. Build the actual original-Fedora initrd and qualify the host codec.
set -Eeuo pipefail
[[ $# == 4 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
boot=$(realpath "$1");early=$(realpath "$2");previous=$(realpath "$3");result=$(realpath -m "$4")
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result"
jq -e '.original_root_guard_unchanged and (.boot_hooks_added|not) and .no_python_payload' "$previous" >/dev/null
cp -a "$boot" "$work/recipe"
bash "$here/integrate-initrd.sh" "$work/recipe" "$early/builder"
bash "$here/apply-boot-profiles.sh" "$work/recipe"
(cd "$work/recipe";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
bash "$early/builder/tests/early-super-policy.sh"
bash "$early/builder/tests/early-super-units.sh"
bash "$work/recipe/src/boot/make-initramfs-base.sh" "$work/expanded" 7.3.4-3-unstable > "$result/dracut.log" 2>&1 || { tail -n40 "$result/dracut.log";exit 1; }
base=$work/expanded/base
cmp "$boot/src/boot/dracut/root-guard.sh" "$base/usr/libexec/uke-root-guard"
for script in early-super-policy prepare-early-super guard-early-rescue map-fastboot-rescue;do
 cmp "$early/builder/src/image/$script.sh" "$base/usr/libexec/uke-super/$script.sh"
done
unit=$base/usr/lib/systemd/system/uke-super-prepare.service
cmp "$early/builder/src/image/dracut/96uke-super-boot/uke-super-prepare.service" "$unit"
grep -Fxq 'ExecStart=/usr/libexec/uke-super/guard-early-rescue.sh' "$base/usr/lib/systemd/system/uke-root-guard.service.d/60-uke-super.conf"
SYSTEMD_LOG_COLOR=0 SYSTEMD_LOG_LEVEL=warning systemd-analyze --root="$base" --man=no verify uke-root-guard.service uke-super-prepare.service > "$result/units.log" 2>&1 || { tail -n30 "$result/units.log";exit 1; }
: > "$result/codec-results.txt"
for compiler in g++ clang++;do
 for mode in plain sanitized;do
  flags=()
  [[ $mode != sanitized ]] || flags=(-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$compiler" -std=c++20 -O2 -Wall -Wextra -Werror "${flags[@]}" "$work/recipe/src/boot/boot-image.cpp" -o "$work/codec"
  readelf -h "$work/codec" | grep -F AArch64
  bash "$boot/tests/boot-image-contract.sh" "$work/codec" >> "$result/codec-results.txt"
  bash "$boot/tests/bootloader-compat-contract.sh" "$work/codec" >> "$result/codec-results.txt"
  bash "$here/../../../tests/boot-super-profiles734.sh" "$work/codec" >> "$result/codec-results.txt"
 done
done
[[ $(grep -c '^PASS: boot super profiles' "$result/codec-results.txt") == 4 ]]
cat "$result/codec-results.txt"
expanded=$(stat -c%s "$work/expanded/base.cpio.gz")
baseline=$(jq -er .base_cpio_gzip_bytes "$previous")
((expanded>=baseline && expanded<=67108864))
jq -n --argjson baseline "$baseline" --argjson expanded "$expanded" \
 --argjson raw "$(du -sb "$base" | cut -f1)" \
 '{schema_version:1,architecture:"aarch64",base_cpio_gzip_bytes:$baseline,
   early_cpio_gzip_bytes:$expanded,extra_cpio_bytes:($expanded-$baseline),expanded_root_bytes:$raw,
   estimated_image_bytes:(70003200+$expanded-$baseline),boot_capacity_bytes:100663296,
   estimate_with_4mib_reserve_fits:(70003200+$expanded-$baseline+4194304+4096<=100663296),
   original_physical_root_guard_preserved:true,actual_dracut_units_verified:true,
   explicit_seed4_profile:true,legacy_codec_contracts_retained:true,new_codec_modes:4,
   no_python_payload:true,contains_actual_kernel_image:false,swap_activated:false,
   physical_device_accessed:false,root_booted:false,hardware_key_release_qualified:false}' > "$result/measurement.json"
jq -e .estimate_with_4mib_reserve_fits "$result/measurement.json"
cp "$work/recipe/lock.json" "$result/boot-source-lock.json"
cat "$result/measurement.json"
