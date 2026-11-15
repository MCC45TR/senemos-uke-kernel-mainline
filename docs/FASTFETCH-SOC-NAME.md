# Uke processor product name

7 November 2026, Fedora Rawhide AArch64, original fastfetch2.70.0-1.fc46,
7.3.3-1-unstable. `/proc/cpuinfo` already reports
`Qualcomm Snapdragon 7+ Gen 3` in both model name and Hardware for all eight
processors. The existing `patches/boot/0007-uke-cpu-hardware-name.patch` and
`tests/cpu-hardware-name-contract.sh` are retained in the next cumulative build.
MIDR, cluster topology, frequencies and the actual SoC ID643 remain unchanged.

Fastfetch nevertheless reports cliffs. In its unmodified2.70.0 source,
`detectCPUOthers()` calls `detectSocName()` before parsing cpuinfo. The latter
selects the last suitable DT compatible, here qcom,cliffs. Its Qualcomm product
lookup does not include643, then falls back to the compatible's model string.
Because a name is now present, cpuinfo is never parsed. Changing cpuinfo again,
DT model or soc0/machine therefore cannot fix this installed application.

The genuine compatible list is xiaomi,uke / qcom,sm7675 / qcom,cliffs. Replacing
these hardware match identities with display text, manufacturing an SoC ID,
hiding compatible from applications or changing its ABI is not an acceptable
driver fix. The DT specification defines compatible as a device programming
model, not a free-form product-name property. The exact requested Fastfetch
output requires an original-upstream product mapping or detection change.

No Fastfetch clone, fork, replacement RPM, configuration override or runtime
kernel change is made. A minimal upstream proposal is retained below; it is
neither submitted to upstream nor installed by the kernel recipe:

```diff
--- a/src/detection/cpu/cpu_linux.c
+++ b/src/detection/cpu/cpu_linux.c
@@ -259,6 +259,10 @@ bool ffCPUQualcommSnapdragonToName(FFstrbuf* name, char* compatibles) {
     const char* soc = nullptr;
     switch (soc_id) {
+        // SM7675 / cliffs
+        case 643:
+            soc = "7+ Gen 3";
+            break;
         // glymur
         case 662:
             soc = "X2 Elite Extreme X2E-94/96-100";
```

## Evidence and attribution

- Fastfetch2.70.0 commit17bb3fd2384bd814b421d73b8c8b8d08e06cfa26,
  `src/detection/cpu/cpu_linux.c`, MIT, Linus Dierheimer and Carter Li.
  The exact file and license remain unchanged in
  `referances/fastfetch-name-20261107/`. This is reference inspection, not an
  application checkout or build. The inspected current dev source also lacks
  case643 and retains DT-before-cpuinfo detection.
- [Original source](https://github.com/fastfetch-cli/fastfetch/blob/17bb3fd2384bd814b421d73b8c8b8d08e06cfa26/src/detection/cpu/cpu_linux.c).
- [DT compatible semantics](https://devicetree-specification.readthedocs.io/en/stable/devicetree-basics.html#compatible).
- Actual read-only device evidence: fastfetch JSON name cliffs/vendor Qualcomm,
  soc0/soc_id643, cpuinfo eight correct product names and genuine compatible
  list. No new hardware acceptance follows from a label inspection.
