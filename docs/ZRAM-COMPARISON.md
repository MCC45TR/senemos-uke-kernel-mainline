# Separate zram laboratory comparison

24 October 2026. Linux 7.2.12 source and Fedora Rawhide tools. This optional
candidate follows the MGLRU comparison. Restore its control configuration before
testing zram so the two changes can be measured independently.

[The kernel fragment](../configs/experiments/zram.config) enables loadable
zram/zsmalloc with LZ4 and ZSTD backends and an initial LZ4 selection. Writeback,
recompression and memory tracking stay disabled. Production native.config,
packaging and boot policy do not include this fragment.

The ARM64 Kconfig check first requires the resolved control to match the
committed native configuration byte for byte. Missing Uke symbols or a different
source/compiler context fail before comparison. It then resolves the candidate and
rejects changes outside zram/zsmalloc. AArch64 object compilation covers zram,
zsmalloc and both backends. A complete matched kernel/module RPM and recoverable
boot qualification remain required before device activation.

Run the host configuration check against the pinned, prepared Linux source:

~~~sh
bash tests/zram-config-contract.sh /path/to/prepared/linux-7.2.12
~~~

[The runtime input](../configs/experiments/zram-generator.conf) is for the original
Fedora zram-generator package. It describes a 1 GiB laboratory swap device
at priority 100. Retain the independently managed disk swap; the recorded Uke
control uses priority 10. This input is not installed by the kernel package.
The original generator package is sufficient; its zram-generator-defaults
subpackage would introduce a separate distribution policy.

The host generator check takes an already verified original executable:

~~~sh
bash tests/zram-generator-contract.sh /path/to/verified/zram-generator
~~~

Run it as an unprivileged user on AArch64 or in an isolated AArch64 SDK. It uses
the upstream test-root interface and blocks external helpers. It checks empty,
laboratory, kernel-disabled and invalid-input cases. Generated units and parser
results do not qualify actual compression, swap I/O, teardown or recovery.

After matched-package verification and thermal checks, compare the same bounded workload
with zram disabled, then LZ4, then ZSTD. Keep MGLRU, THP, CPU/GPU policy, desktop,
disk swap and thermal controls fixed. Record memory/IO PSI, CPU, interaction
latency, OOM events, zram statistics and energy. Benefits and production sizing
remain measurement questions.
