#!/usr/bin/bash
# COPR only. Measure original Fedora tool closure without installing boot hooks.
set -Eeuo pipefail
[[ $# == 3 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
boot=$(realpath "$1");tools=$(realpath "$2");result=$(realpath -m "$3")
[[ -d $boot && -d $tools && ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result"
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
bash "$boot/src/boot/make-initramfs-base.sh" "$work/base" 7.3.4-3-unstable > "$result/base.log" 2>&1 || { tail -n40 "$result/base.log";exit 1; }
cp -a "$boot" "$work/augmented-recipe"
recipe=$work/augmented-recipe/src/boot/make-initramfs-base.sh
mkdir -p "$work/augmented-recipe/packaging/uke-super-tools"
cp "$tools/"*.sh "$work/augmented-recipe/packaging/uke-super-tools/"
awk '
 {print}
 $0=="cp -a /usr/lib/dracut/. \"$work/dracut/\""{
  print "# UKE_SUPER_TOOLS734_BEGIN"
  print "mkdir -p \"$work/dracut/modules.d/95uke-super-tools\""
  print "cp \"$here/../../packaging/uke-super-tools/\"*.sh \"$work/dracut/modules.d/95uke-super-tools/\""
  print "chmod 755 \"$work/dracut/modules.d/95uke-super-tools/\"*.sh"
  print "# UKE_SUPER_TOOLS734_END";n++
 }END{if(n!=1)exit 1}
' "$recipe" | sed 's/--add uke-abl --kernel-cmdline/--add "uke-abl uke-super-tools" --kernel-cmdline/' > "$work/augmented.sh"
awk '/^# UKE_SUPER_TOOLS734_BEGIN$/{skip=1;next}/^# UKE_SUPER_TOOLS734_END$/{skip=0;next}!skip{print}' "$work/augmented.sh" |
 sed 's/--add "uke-abl uke-super-tools" --kernel-cmdline/--add uke-abl --kernel-cmdline/' | cmp - "$recipe"
install -m644 "$work/augmented.sh" "$recipe"
bash -n "$recipe"
bash "$recipe" "$work/expanded" 7.3.4-3-unstable > "$result/expanded.log" 2>&1 || { tail -n40 "$result/expanded.log";exit 1; }
cmp "$work/base/base/usr/libexec/uke-root-guard" "$work/expanded/base/usr/libexec/uke-root-guard"
base=$(stat -c %s "$work/base/base.cpio.gz")
expanded=$(stat -c %s "$work/expanded/base.cpio.gz")
((expanded>=base && expanded<=67108864))
for script in fastboot-singleboot-layout inspect-fastboot-super plan-super-provision provision-fastboot-super map-fastboot-rescue select-uke-super;do
 cmp "$tools/$script.sh" "$work/expanded/base/usr/libexec/uke-super/$script.sh"
done
jq -n --argjson base "$base" --argjson expanded "$expanded" \
 --argjson raw "$(du -sb "$work/expanded/base" | cut -f1)" \
 '{schema_version:1,architecture:"aarch64",base_cpio_gzip_bytes:$base,expanded_cpio_gzip_bytes:$expanded,
   extra_cpio_bytes:($expanded-$base),expanded_root_bytes:$raw,
   measured_7342_image_bytes:70003200,estimated_image_bytes:(70003200+$expanded-$base),
   boot_capacity_bytes:100663296,estimate_with_4mib_reserve_fits:(70003200+$expanded-$base+4194304+4096<=100663296),
   contains_actual_kernel_image:false,original_root_guard_unchanged:true,boot_hooks_added:false,
   no_python_payload:true,physical_device_accessed:false,boot_or_key_admitted:false}' > "$result/measurement.json"
cat "$result/measurement.json"
