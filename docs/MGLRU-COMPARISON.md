# MGLRU comparison preparation, 24 October 2026

Environment: Linux 7.2.12, Uke native configuration from source
`4ee3b4be779318bc61885c0287c570ba22cb7442` (release 24).
This optional laboratory fragment is not selected by a production recipe.

The checker first requires the resolved control to match the committed native
configuration byte for byte. Missing Uke symbols or a different source/compiler
context cause failure before the experiment is compared.

Resolve `packaging/native/native.config` with the normal ARM64 Kconfig first.
Resolve a second output with `configs/experiments/mglru.config` appended. Keep
the original configuration as the unchanged baseline and compare all resolved
values. The candidate supplies the upstream runtime interface with MGLRU off
by default and full historical debug statistics disabled. It changes neither
THP, zram, zswap nor distribution OOM policy. Do not port Android reclaim code
or select a minimum-TTL policy for this initial comparison.

Before a binary delivery, allocate a fresh kernel release and build the complete
matched Image, modules, DT and boot container through the normal recipe. Qualify
that tuple and recovery route on Uke before changing its runtime reclaim policy.
Compare runtime off/on with the same kernel, applications, workload, swap,
display mode and thermal controls. Record pressure totals over the same monotonic
interval, reclaim/swap/OOM counters, interaction latency, CPU and physical energy.
Interface availability and a successful Kconfig check do not establish benefit.

Host check, using an equipped LLVM SDK and the prepared project Linux source:

```sh
bash tests/mglru-config-contract.sh "$kernel_source"
```

The test resolves both full configurations and refuses any non-MGLRU option
difference. It neither builds a kernel nor changes runtime memory controls.

Sources: the dated OEM/same-SoC/upstream comparison is recorded as OPT-05 in the
central lesson `UKE-OPT-I001`. The mechanism and runtime ABI are the existing
[upstream MGLRU implementation](https://docs.kernel.org/admin-guide/mm/multigen_lru.html);
stall accounting follows the [PSI interface](https://docs.kernel.org/accounting/psi.html).
No donor code, board values, custom daemon or tablet test script is added.
