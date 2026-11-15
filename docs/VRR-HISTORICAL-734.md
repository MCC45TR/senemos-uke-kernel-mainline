# Preserve the MST source ledger after native VRR

16 November 2026. Full candidate 11332055 built the Image and passed the
earlier linked/source checks, including the reviewed Kconfig compatibility
projection. It stopped at the original MST five-file source ledger: the new
VRR default intentionally changes dpu_encoder.c after that ledger is created.
No runtime RPM was released and the full release remains 7.3.4-2.

The new check validates the exact qualified VRR postimage and inverse patch,
copies the five admitted source files, and reverses only that VRR patch in
the temporary copy. The original ledger then checks all five files unchanged.
The actual production source and linked objects keep native VRR. No ledger
digest, MST symbol check, storage configuration check or original linked
validation is removed. A complete script inverse preserves the original
prepared MST checker, including its full28 storage adaptations.

The PC data fixture uses the real qualified DPU postimage and four synthetic
files. It accepts the exact inverse and rejects unrelated changes in each file,
a duplicate ledger, changed historical identity, missing production receipt and
changed inverse patch. This is not compilation. Source check13 runs the same
gate on the actual five prepared sources before compiling the native ARM64
objects, so this full-check boundary is exercised before another Image build.

The remaining full-check tail was reviewed for the affected files. Surround,
PCM, sensor, battery, module-signature and final camera/UFS/TEE checks retain
their original source scopes and independent earlier inverses. Native13,
the next full build, signed DNF and physical VRR/audio tests remain separate.
