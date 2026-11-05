# Kernel Manager capabilities

Date: 2026-11-05. The source baseline is the post12203 governor/audio/pogo
union 772775e39f631156d8161cdf96f5e5b37d532365, qualified by COPR11262989.
This layer is an additive source/configuration check, not a kernel release.
The camera coordinator retains ownership of the cumulative integration queue.

`configs/kernel-manager/resources.config` adds task/group utilization clamps,
CPU bandwidth control, TEO, modular zram with LZO/LZ4/Zstd, MGLRU compiled with
its boot default off, DAMON interfaces, cgroup I/O controls, scheduler/delay
accounting and thermal statistics. BBR and FQ/FQ-CoDel are optional modules;
the default CPU frequency, CPU idle, thermal and TCP policies are preserved.
No zram device, DAMON operation, scheduler program or cgroup limit is started
by compiling these options. These are generic upstream facilities; no donor
hardware driver, DT supplier, OPP or camera/calibration contract is changed.

The independent `sched-ext-experimental.config` is research input only. It
requires BTF/debug-info and a qualified userspace BPF scheduler. It is not
part of the normal resource fragment or automatic activation. Compilation
alone cannot qualify scheduler latency, battery use or recoverability.

The COPR source factory retains the frozen12203 source and every original
postfreeze source/config/refusal/callback/object gate before the manager
extension. It independently resolves native, CDSP and Waydroid references,
checks the exact intent/dependency closure and retains the complete config
outside that closure. The original full NFC and hardening comparators are
run again. Fourteen additional AArch64 objects exercise the selected features;
only a text receipt is packaged. No Image, final module, installed kernel,
slot, profile or boot preference is changed.

Production integration must carry the same fragment into all three config
inputs and the boot recipe, preserve the original and governor-only reference
histories, and extend the admission chain rather than replacing the old CDSP
snapshot or weakening the NFC comparator. Later camera/audio/SSC contributions
remain mandatory. Physical and workload qualification follow only after the
coordinator delivers a cumulative unstable kernel.

Upstream interface references: [uclamp](https://docs.kernel.org/scheduler/sched-util-clamp.html),
[cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html),
[zram](https://docs.kernel.org/admin-guide/blockdev/zram.html),
[MGLRU](https://docs.kernel.org/admin-guide/mm/multigen_lru.html),
[sched_ext](https://docs.kernel.org/scheduler/sched-ext.html).
