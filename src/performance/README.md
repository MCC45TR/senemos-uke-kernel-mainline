# Cliffs7 LLCC source candidate

20 October 2026. Native Linux 7.2.11 source and host-only Fedora fixtures.
Two inactive patches describe the exact Cliffs7 slice policy and a native
five-window binding. The existing 94-patch series and kernel release remain
unchanged. No target package or boot result is established.

The source uses MiCode Uke kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
DT `94c84aeb9e517dbde546fc732033c184094c8e57`, the matching Nord 4 policy
`fc892483f1d61f245924681eb5abd563564d9cba` and upstream
`f47d223627f80cb7a1eb14c585fe6cb35de5e984`. Copyright and GPL attribution stay
with the translated data. See the [source/check manifest](../../manifests/llcc-source-candidate-20261020.json).

The driver candidate validates four 2 MiB banks, the OEM broadcast window,
hardware bank count and v5 version before configuration writes. It retains
all 17 OEM slices, using the native MODPE/WRCACHE names for the same numeric
use-case IDs. EDAC creation is disabled pending its exact access/IRQ contract.
Native Adreno already has the A7xx cache-field path; no Android GPU driver,
frequency lock or performance table is imported.

Apply the two patches in numeric order to a matching prepared source tree.
The following commands exercise the actual probe, configuration and A7xx
cache-field source, followed by the synthetic DT/binding cases:

```bash
bash tests/llcc-sm7675-contract.sh "$kernel"
CC=clang LLCC_TEST_CFLAGS='-O1 -fsanitize=address,undefined -fno-omit-frame-pointer' \
    bash tests/llcc-sm7675-contract.sh "$kernel"
dt-doc-validate "$kernel/Documentation/devicetree/bindings/cache/qcom,llcc.yaml"
dt-mk-schema -j "$kernel/Documentation/devicetree/bindings/cache/qcom,llcc.yaml" \
    "$kernel/Documentation/devicetree/bindings/nvmem/nvmem-consumer.yaml" > processed-schema.json
bash tests/llcc-sm7675-dt-contract.sh processed-schema.json
```

dt-schema 2026.09 and its unmodified upstream Python tools run only in the
existing host schema SDK. No Python or new runtime dependency is introduced
on the tablet. GCC fixtures use O0 to avoid alias-analysis false positives
across simulated regmap calls; Clang sanitizer checks use O1. The real LLCC
AArch64 object compiles with `KCFLAGS=-Werror`.

`prepare-llcc-dt.sh` accepts an already adapted Uke/SM7675 base DT with the
exact OEM Cliffs7 node. It writes a new mode-0600 candidate, preserves its
input and refuses an existing output, including a symlink. It converts only
the cache-controller resources, removes legacy configuration/debug metadata
and preserves the remaining graph. It is host-only and is not called by the
normal boot producer. Never substitute its output for an accepted boot DT
without the separate matched-package and recovery checks.

Next work is the normal boot producer integration and GPU/provider startup
and lifetime checks, followed by a matched package. Four-bank/v5 admission,
partial-programming recovery, cache coherency, suspend and performance still
require a recoverable device test. Source fixtures do not establish any of
those results. Preserve the accepted rollback, charging and thermal policy.
