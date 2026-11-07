#!/usr/bin/env bash
# Check actual complete configurations and native objects, never target policy.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Cumulative kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:?objects or linked}
[[ $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
meta=$profile/source-composition.json
before=$profile/history-before-memory-compression
(cd "$before";sha256sum -c --strict --quiet SHA256SUMS)
old=$(jq -er .memory_compression_previous_native_config_sha256 "$meta")
new=$(jq -er .migration_native_config_sha256 "$meta")
printf '%s  %s\n' "$old" "$before/native.config" "$new" "$profile/native.config" | sha256sum -c --strict --quiet -
cmp "$profile/native.config" "$kernel/boot-recipe/packaging/native/native.config"
cmp <(cat "$before/resources.config" "$profile/configs/memory-compression733.config") "$profile/configs/kernel-manager/resources.config"
cmp <(sed '/^CONFIG_ZSMALLOC=m$/d' "$before/resource-dependencies.txt";printf '%s\n' CONFIG_842_COMPRESS=m CONFIG_842_DECOMPRESS=m CONFIG_LZ4HC_COMPRESS=m 'CONFIG_ZSWAP_COMPRESSOR_DEFAULT="lz4"') "$profile/configs/kernel-manager/resource-dependencies.txt"
# The historical checker changes only its authenticated complete-config hash.
sed "s/$new/$old/g" "$profile/packaging/native/check-cumulative-camera731.sh" | cmp - "$before/check-cumulative-camera731.sh"
for line in CONFIG_ZRAM=m CONFIG_ZRAM_BACKEND_LZO=y CONFIG_ZRAM_BACKEND_LZ4=y \
 CONFIG_ZRAM_BACKEND_ZSTD=y CONFIG_ZRAM_DEF_COMP_LZORLE=y \
 'CONFIG_ZRAM_DEF_COMP="lzo-rle"' CONFIG_CRYPTO_LZ4=y CONFIG_CRYPTO_ZSTD=m;do
 grep -Fx "$line" "$out/.config"
done
while IFS= read -r line;do
 [[ -z $line || ($line == \#* && $line != '# CONFIG_'*) ]] || grep -Fx "$line" "$out/.config"
done < "$profile/configs/memory-compression733.config"
grep -Fx 'CONFIG_ZSWAP_COMPRESSOR_DEFAULT="lz4"' "$out/.config"
grep -Fx '# CONFIG_ZRAM_WRITEBACK is not set' "$out/.config"
grep -Fx '# CONFIG_LRU_GEN_ENABLED is not set' "$out/.config"
jq -e '.memory_compression_layer==1 and .memory_compression_zram_extra_backends==["lz4hc","deflate","842"] and .memory_compression_zram_multi and .memory_compression_zswap_built and (.memory_compression_zswap_default_enabled|not) and .memory_compression_no_swap_policy_change and .speaker_gain_ceiling==223 and (.physical_acceptance|not)' "$meta" >/dev/null
for object in drivers/block/zram/zram.o mm/zswap.o mm/zsmalloc.o;do
 test -s "$out/$object"
 llvm-readelf -h "$out/$object" | grep -E 'Machine:.*AArch64'
done
for name in lzo lzorle lz4 lz4hc zstd deflate 842;do
 llvm-nm --defined-only "$out/drivers/block/zram/zram.o" | grep -E " [DR] backend_$name$"
done
llvm-nm --defined-only "$out/drivers/block/zram/zram.o" | grep -E ' t recompress_store$'
for symbol in zswap_load zswap_store;do llvm-nm --defined-only "$out/mm/zswap.o" | grep -E " [tT] $symbol$";done
llvm-nm --defined-only "$out/mm/zsmalloc.o" | grep -E ' T zs_malloc$'
if [[ $phase == linked ]];then
 modinfo -F vermagic "$out/drivers/block/zram/zram.ko" | grep -F "$(jq -er .kernel_release "$meta") "
 grep -E '(^|/)mm/zsmalloc[.]ko$' "$out/modules.builtin"
fi
printf 'Actual cumulative memory compression: seven ZRAM backends/multi, Zswap default-off/LZ4 with Zstd available, builtin allocator and complete config gates passed:%s; pressure/performance acceptance separate.\n' "$phase"
