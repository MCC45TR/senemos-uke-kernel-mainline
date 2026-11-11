# Read-only remote processor crash history

The existing process-context crash event covers subscribers already listening.
If firmware crashes and recovers before userspace subscribes, `state=running`
alone cannot recover that history. The candidate `crash_count` sysfs attribute
exposes the framework's existing unsigned counter without modifying the crash
worker, IRQ path, firmware commands or recovery policy. Reads do not wake or
wait for firmware. The existing change event remains the notification source.

Control subscribes first, then reads the current state and count. A positive
count still identifies a handled crash after recovery; its normal boot/kernel/
slot-state binding and verified fallback checks remain necessary. An old kernel
with no attribute retains event/state monitoring and reports the history gap.
A present but invalid counter is unavailable health, never a fabricated zero
or proof of a crash. A live crashed state takes precedence. No polling timer,
new daemon or runtime package is needed.

This counter belongs to the registered remoteproc object. It survives ordinary
firmware recovery and stop/start, resets when that object is recreated and may
wrap after UINT_MAX as the existing framework counter does. It does not retain
history across reboot or qualify kernel-panic, GPU, UFS or power-loss detection.
It is not an atomic snapshot of state and count.

Primary comparison: signed Linux 7.3.3 at
`d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`,
`drivers/remoteproc/remoteproc_core.c` (blob
`1ed406714849185767a9f3461822d54b43c49eb9`),
`drivers/remoteproc/remoteproc_sysfs.c` (blob
`925b0cdbe57788cfedaef668868624293e42135b`) and
`include/linux/remoteproc.h` (blob
`a44368737b39a52a11177204b70f58064bab53fe`), retaining upstream GPL-2.0
attribution. Current upstream sysfs blob
`c37736ff4acc63402e9a88ddb8c6a1680fa79930` also lacks this counter. No equivalent
standard history endpoint was found in that bounded review. The generic ABI
does not transplant Uke OEM or another board's register, firmware or calibration
values; existing Qualcomm/Uke crash reporting remains authoritative.

Source admission requires the entire sysfs-file inverse, unchanged cumulative
crash-worker hash, actual callback format/read-only checks and the real ARM64
sysfs object. Device acceptance separately requires a recoverable real DSP
fault before and after monitor startup, permissive/enforced/off logging,
verified fallback and retained A/B recovery. Compilation alone does not prove
fault handling or physical stability.
