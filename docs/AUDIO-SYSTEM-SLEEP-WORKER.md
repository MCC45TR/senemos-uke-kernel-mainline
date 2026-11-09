# Freeze amplifier health work during system sleep

9 November 2026. Kernel9 recorded an amplifier health timeout followed by I2C
`Transfer while suspended` in `fs19xx_unmute_work`. Later graph40 opens failed;
ADSP remained running when evidence was collected. This does not establish the
root cause of every USB, battery, display or DSP incident.

The current codec uses five delayed-work scheduling sites on
`system_percpu_wq`: initial unmute, bounded PLL/configured waits, periodic active
health and the finite muted STOP deadline. This queue is not freezable. The
candidate changes only those five queue pointers to `system_freezable_wq`.
Linux drains freezable work during the system-freeze phase and does not start
new work until thaw. Thus this worker cannot start I2C transfers in the device
suspend interval. Existing component suspend/resume, locking, cancellation,
poweroff, STOP deadlines, fault handling, registers, gain223 and protection are
unchanged. Runtime-PM/resource ordering and physical sleep remain separate work.

Linux7.3.3 `d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`, GPL-2.0,
`include/linux/workqueue.h` describes the queue and exports it. The upstream
core-api workqueue documentation specifies the WQ_FREEZABLE drain/thaw contract.
The exact Uke OEM FourSemi implementation and existing protected driver were
reviewed previously; no other-board register or calibration values are copied.
A same-SoC native FS19xx system-sleep fix is not established by the pinned donor
inventory. The observed stack and upstream queue contract motivate this narrow
change, rather than a claimed OEM port.

Qualification runs the actual codec/runtime/STOP callbacks with distinct queue
providers at HZ100/250/1000 and GCC/Clang with/without sanitizers. The historical
nonfreezable sites must fail the same provider check. A complete source inverse
must recover the exact admitted codec; a fresh real ARM64 codec object must
import system_freezable_wq and no longer import system_percpu_wq. These checks
do not execute Linux device suspend on a tablet or prove physical protection.
Require recoverable repeated audio/DP/USB suspend and resume tests before any
physical success claim. No new worker, timer, daemon or runtime package is added.
