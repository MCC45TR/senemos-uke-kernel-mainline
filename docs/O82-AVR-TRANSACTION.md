# O82 dual-interface AVR period recovery

8 November 2026. Candidate source; native qualification and device acceptance
are separate. No new daemon, RPM, DT property or panel command is introduced.

The cumulative live-retime callback writes each INTF's AVR period before the
common CTL flush. Previously, a second write/readback error or unequal target
period returned without restoring the first register. Its atomic caller then
entered the existing pre-flush quarantine and required recovery. The old test
deliberately expected AVR to remain enabled after an error.

The new transaction validates both active interfaces and their callbacks,
snapshots both nonzero periods and refuses an already unequal pair before
writing. It serializes MMIO with the existing encoder spinlock and rechecks
AVR admission after taking that lock. Successful programming requires matching
target periods and final readback from both interfaces.

On failure, both saved periods are restored and checked, including the interface
whose write may have partially failed. Failure is latched to prevent page-flip
retry. If restoration cannot be verified, both local AVR enables are cleared
and software admission is revoked. This is best-effort register containment,
not a claim that a failed MMIO device obeyed the disable write.

Restoring AVR periods does not restore the DSI host or the preceding timing
changes. The callback always returns the original error, or EIO if rollback
fails, preserving the caller's existing quarantine/recovery requirement. A
complete modeset fallback remains a separate task. No physical failure has
been reproduced on the tablet in this work.

The existing seven modes, panel suppliers, requested30Hz floor, capability API,
watchdog, DP, touch, brightness, protected223 audio and A/B flow remain. The
change adds MMIO reads only during an existing live-retime transaction; it adds
no healthy-idle timer or sensor subscription.

Source references: project59966c3d88efbeaaa4cf133b9ef09a24ba1667d9,
patches/display/0034 and0042; Linux7.3.3 at
d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd; exact Uke MiCode display
44275c404a677d9d9e5230fedd1af2ef02fc7b9a, msm/sde/sde_hw_intf.c
AVR_VTOTAL/CONTROL contract. No new register value or adjacent-board setting
is imported. The implementation follows existing GPL-2.0-only kernel code.
The downstream interfaces differ from upstream DPU and are not copied as a
replacement driver. No applicable same-SoC donor supplies this project-specific
transaction; the existing local two-INTF admission remains authoritative.

Qualification runs the actual encoder and MMIO callbacks with controlled
providers under GCC and Clang, plain and ASan/UBSan, including partial writes,
snapshot/readback failures, unequal periods, provider loss, lock-time revocation
and failed restoration. Three compiled behavioral mutants must be refused.
Real ARM64 encoder/INTF objects and the final MSM module are checked separately.
The original source suites run before this late patch and remain tied to the
same cumulative source receipt. These checks are not physical VRR acceptance.
