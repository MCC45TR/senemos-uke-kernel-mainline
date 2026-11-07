# Upstream memory compression capabilities

7 November2026. Three tracker items are planned for the next cumulative full
kernel: corrected native speaker enable readback, additional ZRAM backends and
multi-compression, and Zswap support. Sound/gain243, stationary closed-cover
boot and brightness remain the ordered hardware priorities.

The actual7334 kernel has ZRAM with LZO/lzo-rle, LZ4 and Zstd. LZ4HC,
Deflate,842, multi-compression and Zswap are absent. Linux733/d50d994b
provides the requested implementations without a fork. Exact upstream
drivers/block/zram/Kconfig/Makefile, its backends, mm/Kconfig and lib/Kconfig
define their dependencies. These are generic memory mechanisms, not a new
SM7675 hardware protocol or a transplanted OEM board value. No DT change is
required. Upstream file-level GPL attribution is preserved; no compression
implementation is copied into a project alternative.

The extension adds the three missing ZRAM backends and multi-compression.
It builds Zswap with an LZ4 default compressor and the retained Zstd crypto
module available. Zswap remains disabled by default, ZRAM keeps lzo-rle,
writeback remains disabled and no swap device or desktop policy is activated.
Zswap selects a built-in Zsmalloc allocator, replacing the prior module in
the new ABI only. Its presence must be checked in the actual objects and
modules.builtin; a lower module count alone is not a removed capability.

Every manager reference and embedded-boot configuration uses the same extended
intent fragment. Existing full config comparisons and unrelated-mutation
refusals remain. The allocator change is an explicit intent, rather than a
hidden dependency override. Historical fragment, dependencies, config and
checker are retained and authenticated. The historical checker changes only
its complete native-config digest. New gates check the actual final flags,
all seven backend descriptors, recompression and Zswap/allocator AArch64
objects, and the final module/built-in linkage.

These are source/build gates, not memory-pressure or performance acceptance.
After matched COPR/DNF/A-B delivery, test bounded compression/decompression
on an exclusively owned disposable RAM device without touching existing
swap/storage. Qualify actual secondary recompression separately. Zswap cache
and pressure/latency/energy comparisons need a reviewed swap topology and
recovery test; compiling it does not establish a benefit or enable it.
