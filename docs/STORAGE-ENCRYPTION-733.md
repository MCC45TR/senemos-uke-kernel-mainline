# Storage encryption capability candidate

The running 7.3.3-9 and admitted cumulative source52 disable `DM_CRYPT` and
`FS_ENCRYPTION`. An older repository config enables them, but is not the
configuration used by that cumulative release. The actual source archive and
running kernel are the evidence for this work.

This source candidate enables standard upstream dm-crypt and dm-inlinecrypt
modules, per-file fscrypt, its default algorithms and blk-crypto software
fallback. It retains the native UFS crypto/Qualcomm ICE and QTEE paths, signed
modules, existing filesystem support and every unrelated configuration option.
The resolved delta is closed and the actual ARM64 crypto/filesystem objects
are compiled. No custom encryption implementation or new runtime package is
introduced.

These capabilities are not an encrypted-system delivery. Current boot helpers
still expect the existing unencrypted root layout and omit cryptsetup from the
initramfs. A future image needs original Fedora cryptsetup/systemd integration,
mapper-aware root admission, A/B recovery and real encrypted I/O/key-lifecycle
tests. This candidate does not format a volume, load a key, change a mount,
replace firmware, alter partitions or issue TEE commands.

Upstream 7.3.3 states that dm-inlinecrypt currently has no cryptsetup/LUKS
integration. Enabling it does not make ordinary dm-crypt use ICE. FDE/LUKS2,
fscrypt with inline encryption and hardware-wrapped key provisioning have
different acceptance gates. The ICE driver supports optional wrapped keys;
the existing raw/wrapped selection is not changed by this source work.
Presence of `/dev/tee0` does not prove a usable sealing/unwrap TA or recovery.

Reviewed primary references:

- Uke OEM kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
  `arch/arm64/configs/gki_defconfig` blob
  `5d6490f1bc359cb487cf02872ec9827aec9bf8b4`: upstream-style encryption and
  downstream `DM_DEFAULT_KEY` support. No downstream key ABI is transplanted.
- Same-SoC OnePlus common kernel
  `9006cd15161f1c628957b4a4ccbaf11e4db7e459`, GKI config blob
  `2b63bcddc1537b994cb8950a5bbeb0bc70cb9295`: equivalent prerequisites,
  not proof of Uke secure-firmware or key compatibility.
- Linux 7.3.3 `d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`, GPL-2.0-only
  Kconfig files: `fs/crypto/Kconfig` blob
  `cd934e31dec40b5c54cee8ff544361aac9c23c6a`, `drivers/md/Kconfig` blob
  `df27c7d066d23d7bd7fdbb2d59231d7421994323` and `block/Kconfig` blob
  `70e4a66d941ff66ecb0ec34f4f7eff7fd1e4be40`.
- The same upstream revision's `Documentation/block/inline-encryption.rst`,
  `Documentation/filesystems/fscrypt.rst` and
  `Documentation/admin-guide/device-mapper/dm-inlinecrypt.rst` (blob
  `8258a72f00a89224370c17422387831fad712f54`).
- Qualcomm ICE source blob `e256595b9826f3effa0ec7e85980d01d10079a20` and
  UFS host blob `954be9343f42ac14533fb6b585fa1662d0f4c352`, same upstream
  revision. Exact Uke HWKM, TEE TA and encrypted I/O acceptance remain open.

Keep both full-system block encryption and per-file encryption in the external
tracker. Neither is replaced by disabling encryption or merely exposing an API.
