# Linux 7.3 Cliffs video candidate

Date: 25 October 2026. Base: `470d18160dac9f9adf65ee8ff6f86472573504c1`,
the physical POCO Pad X1 Linux 7.3.0-3 source identity.

This directory remains outside the active source series. No Iris OF match,
boot change, firmware payload or tablet codec acceptance is included.

1. `0001`: rebase six earlier dormant VIDEOCC/Iris candidates from `67c9ee7a`
   onto Linux 7.3, including its generation-specific firmware descriptor and
   the changed VIDEOCC binding condition.
2. `0002`-`0005`: Xilin Wu / Radxa decode-order, CAPTURE maximum, encoder
   deblocking and error timestamp changes, pinned by libva-v4l2 commit
   `6d03c3f8fb19b86f84b2b6c60ff20d1402f0ac41`. Attribution is retained.
3. `0006`: native MVS0C/MVS1C GDSCs acquire the exact OEM MXC/MMCX parent
   voter before clocks; the SM7675 binding requires that supply.
4. `0007`: the exact Uke HLOS Video/SF and Venus configuration interconnect
   routes, sharing existing display/USB/DDR providers and BCMs.
5. `0008`: exact Uke firmware mmap/device regions, checked allocation and
   mapping ownership, error-returning boot setup and PAS shutdown retention.
6. `0009`: exact video SID/ACTLR admission and a shared DMA aperture starting
   at the intersection of the OEM pixel/nonpixel pools.
7. `0010`: reject a missing/deferred controller parent rather than allowing
   the generic GDSC optional-supply lookup to omit it.
8. `0011`: propagate shared Qualcomm reset transport and callback errors.

The offline overlay in `src/video/` resolves against the captured Linux 7.3
handoff FDT while leaving video nodes disabled. The shared nonsecure IOMMU
mapping now uses the exact OEM ACTLR and the common valid DMA range;
equivalence to OEM split ownership still needs firmware/frame tests. The 192 MHz OPP is an initial
source test point, not a supported performance ceiling.

Remaining platform work includes controller retention/reset ordering,
legacy/native provider ownership, SKU-specific HFI capabilities and target
validation of firmware/addressing/teardown. Complete full kernel/RPM validation and a recoverable
firmware/native V4L2 trial before activating this source series. Main10 encode,
extended modes, lifecycle, sustained performance and applications remain
separate required work.
