# Optional CPU and GPU governors

5 November 2026. Target: POCO Pad X1 / SM7675, Fedora Rawhide AArch64.
This contribution follows cumulative source
`d1a7a35247eb76bdcc323b42b3ff46806c7fdccf`. It must be integrated into a later
coordinated unstable candidate; it does not replace the frozen candidate.

## Observed running kernel

On `7.3.1-12101-unstable`, CPUFreq already provides `performance`, `schedutil`,
`ondemand` and `userspace`. Loading the installed `cpufreq_powersave` and
`cpufreq_conservative` modules exposes `powersave` and `conservative` on all
three CPU policies. Their active `schedutil` governor and frequency limits
remain unchanged. Module loading is transient; no persistent target rule was
installed. Senemos Kernel Manager reads the advertised choices on refresh and
excludes `userspace`, which requires a separate frequency control loop.

The Adreno devfreq node currently advertises `simple_ondemand` and `userspace`.
The native configuration omits the standard devfreq `performance` and
`powersave` governors. The UFS devfreq node is a separate provider and must not
be presented or controlled as a GPU.

All physical UFS queues already advertise `none`, `mq-deadline`, `kyber` and
`bfq`, with `mq-deadline` active. No additional upstream I/O scheduler is missing.

## Configuration contribution

Only four native configuration lines change:

| Option | Baseline | Candidate |
|---|---|---|
| `CPU_FREQ_GOV_POWERSAVE` | module | built in |
| `CPU_FREQ_GOV_CONSERVATIVE` | module | built in |
| `DEVFREQ_GOV_PERFORMANCE` | disabled | built in |
| `DEVFREQ_GOV_POWERSAVE` | disabled | built in |

Keep `CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`, the GPU driver's `simple_ondemand`
selection, all existing I/O schedulers, thermal/OPP constraints, DT and hardware
admission gates. These choices do not add frequencies or change voltages.
`performance` requests the highest allowed frequency and `powersave` the lowest;
neither is a measured battery or performance improvement for this tablet.
`conservative` adjusts the CPU frequency gradually according to load.

CPU task scheduling is separate from CPUFreq and disk I/O scheduling. No
`sched_ext`, BTF expansion or out-of-tree scheduler is enabled here. The native
profile currently disables BTF; a task scheduler contribution needs separate
configuration, package and workload qualification.

## Integration and validation

The coordinator must carry these four changes into both native configuration
copies in the next cumulative source recipe, update the corresponding config
hashes/locks and preserve every existing layer. Do not repoint a frozen source
producer or replace an active full-kernel build. No kernel revision, installed
kernel/profile, slot, automatic staging policy or rollback preference changes
as part of this contribution.

`tests/governor-config-contract.sh BASELINE CANDIDATE` requires the four expected
changes and byte-for-byte retention of every other config line. The COPR-only
`packaging/native/copr-governor-check.sh RESULT_DIR` produces text receipts and
compiles the four unchanged upstream governor objects against the SHA-256-pinned
Linux 7.3.1 source with AArch64 `defconfig` and `-Werror`. This bounded check does
not resolve the complete cumulative kernel configuration or qualify final
linkage, boot, thermal behavior or workload performance.

The source worker downloads and verifies the upstream archive before the RPM
build; the archive is supplied as Source1 and checked again inside the isolated
build. Initial check11262118 passed the config comparison but stopped before
compilation because its build chroot could not resolve the source host. The
corrected recipe removes that network dependency from the RPM check.

After coordinated delivery, confirm the two GPU governors appear on the actual
Adreno node and both CPU governors are available without module loading. Keep
the original active governors while inspecting availability. Any selection
trial must read back the chosen provider and restore its initial state.

Primary references: [CPUFreq governors](https://docs.kernel.org/admin-guide/pm/cpufreq.html),
[devfreq Kconfig](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/devfreq/Kconfig),
[I/O scheduler selection](https://docs.kernel.org/block/switching-sched.html),
[sched_ext requirements](https://docs.kernel.org/scheduler/sched-ext.html).
