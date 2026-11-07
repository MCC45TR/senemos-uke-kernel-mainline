# Uke SM7675 scheduling, memory and ThinLTO candidate

7 November 2026. Target: POCO Pad X1 and Xiaomi Pad 7 (uke, Snapdragon 7+ Gen 3 / SM7675), Fedora Rawhide AArch64, Linux 7.3.1. **Proposal and source-only candidate.** No new image, validated full build, BPF scheduler RPM, or physical boot result is claimed.

## Current source baseline

The native build already invokes `ARCH=arm64 LLVM=1 LLVM_IAS=1`; the resolved native configuration uses Clang/LLD, `CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y`, `CPU_FREQ_GOV_SCHEDUTIL=y`, and `ENERGY_MODEL=y`. The source-locked native configuration currently disables `UCLAMP_TASK`, `LRU_GEN`, `PREEMPT_DYNAMIC`, and ThinLTO. It selects `DEBUG_INFO_NONE=y` and does not provide the BTF required by sched_ext. The separate `configs/fedora.config` fragment likewise selects no debug info; simply modifying that fragment would not change the native production image.

The EEVDF fair scheduler is upstream code in Linux 7.3.1. There is no independent `CONFIG_EEVDF` choice. EAS can operate only with valid capacity, CPU frequency and Energy Model inputs, not through `ENERGY_MODEL=y` alone; verify `/proc/sys/kernel/sched_energy_aware` at runtime.

## Proposed compilation cohorts

1. **Base SCX candidate:** apply `configs/uke-performance-scx-candidate.config` to a *development-only* configuration, run `olddefconfig`, then `bash tests/performance-config-contract.sh OUT/.config`. Keep upstream EEVDF as the idle/no-SCX default, schedutil, EAS inputs, UCLAMP, MGLRU, and PREEMPT_DYNAMIC. Enable BTF and sched_ext with the required Clang/LLD `pahole`/dwarves toolchain. `CONFIG_LRU_GEN_ENABLED=y` is a trial default; it has a runtime kill switch.
2. **Separate ThinLTO candidate:** only after base source and tablet qualification, merge `configs/uke-thinlto-candidate.config` as the final LTO fragment, run `olddefconfig` and the same contract with `--thinlto`. Check BTF, modules, boot image size, link memory, build reproducibility and actual system latency before adopting.
3. **BORE patch qualification:** BORE modifies the fair scheduler and is *not* an SCX BPF program. Do not invent a `CONFIG_BORE` setting or import an unreviewed patch. Review an exact Linux 7.3.1-compatible upstream BORE patch and its provenance, compile it in a separate native branch, and test its `kernel.sched_bore` runtime switch before combining with sched_ext. Keep BORE off by default if accepted; `sched_bore=0` is upstream-like EEVDF behavior on a BORE-capable kernel. This assumes the particular imported patch provides that sysctl.
4. **SCX userspace packaging:** package and pin the upstream `scx_lavd` and `scx_p2dq` binaries for Fedora Rawhide AArch64 separately from the kernel. Do not embed these Rust/BPF executables as kernel components. Record scx source version, build dependencies, kernel ABI checks and licenses. Verify both schedulers on the actual ARM64 CPU topology and under thermal/PSI load before making selectable in uke-control.

The released native build copies `packaging/native/native.config` in `src/boot/build-payload.sh`. It then runs `olddefconfig` and source/package contracts. Do **not** inject this fragment after source-lock verification into a production COPR job. A release candidate needs a regenerated and checksum-verified native profile, source archive lock, pinned boot recipe, updated build dependencies (including `dwarves`/pahole), matched modules, package contracts, and a new unstable-only version.

Do not apply whole-kernel `-march=armv8.2-a`, `-mcpu=native` or Cortex-specific `KCFLAGS` blindly: the arm64 kernel's early boot, exception paths and feature alternatives must continue working. The ARMv8.2-A compatibility goal is met through the tested generic arm64 kernel ABI; tune architecture-specific userspace binaries independently.

## Proposed uke-control interface

- `uke-control scheduler list`: report EEVDF, LAVD, P2DQ, and optional BORE with *actual* kernel and installed-program availability.
- `uke-control scheduler status`: read current sched_ext state, running service identity, BORE sysctl (only if present), current cpufreq governor, EAS status and MGLRU state.
- `sudo uke-control scheduler set eevdf|lavd|p2dq|bore`: a privileged, allowlisted operation. Disable an active SCX scheduler before setting the next one. EEVDF requires no active SCX and `sched_bore=0` on BORE-capable builds. BORE requires verified BORE sysctl and `sched_bore=1` with no SCX scheduler active. Refuse unavailable modes; do not advertise availability just because `CONFIG_SCHED_CLASS_EXT=y` exists.
- The GTK and Qt clients must consume the same versioned backend/catalog API. Avoid shell string interpolation, arbitrary binary paths and unsafe privilege escalation; implement authorization through existing service/Polkit policies.
- Fail closed on a missing SCX program, state mismatch or unsupported kernel ABI. The kernel restores its fair scheduler when SCX unloads or errors; preserve EEVDF as the nonpersistent initial boot choice. Persistent scheduler preferences require a separate guarded design and rollback.

EAS/UCLAMP behavior under SCX is scheduler-specific; do not promise that SCX retains every fair-class cgroup or energy policy. In particular, P2DQ documents CPU-hotplug and cgroup-bandwidth limits.

## Acceptance before promotion

Verify the resolved Kconfig (including BTF production, no dropped options), clean source-locked AArch64 compilation, module signing, matched DTBs and boot bundle, and all existing hardening/payload checks. On physical POCO Pad X1 and Xiaomi Pad 7 separately, record boot/suspend/resume, `/sys/kernel/btf/vmlinux`, `/sys/kernel/sched_ext/state`, `/proc/sys/kernel/sched_energy_aware`, `/sys/kernel/mm/lru_gen/enabled`, `schedutil` policy status, switch/fallback tests, memory-pressure outcomes, frame-time 95th/99th percentiles, thermal throttling and energy consumed per task. Retain the accepted boot slot. No claim of a performance improvement is valid before A/B measurements.

Upstream references: [SCX documentation](https://docs.kernel.org/7.3/scheduler/sched-ext.html), [scx project](https://github.com/sched-ext/scx), [MGLRU](https://docs.kernel.org/admin-guide/mm/multigen_lru.html), [LLVM kbuild](https://docs.kernel.org/kbuild/llvm.html), [BORE project](https://github.com/firelzrd/bore-scheduler).
