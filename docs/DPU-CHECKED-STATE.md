# DPU bandwidth from the checked atomic state

6 November 2026, POCO Pad X1 / SM7675, Linux7.3.1.

This contribution backports Joonhoe Kim's upstream commit
[`480ba24aa34031c898d0a711405664cd947bbee4`](https://git.kernel.org/linus/480ba24aa34031c898d0a711405664cd947bbee4),
reviewed and integrated by Dmitry Baryshkov. Its code diff is unchanged.
The original file retains GPL-2.0-only and Copyright2016–2018 The Linux
Foundation. Upstream reported a physical DPMS/resume result on Lenovo TB323FU;
that is not Uke acceptance.

Linux7.3.1 `_dpu_core_perf_calc_bw()` sums the committed CRTC's plane states
while its caller is checking a new atomic state. On re-enable, the committed
state can have no planes and produce a zero average-bandwidth vote despite
incoming scanout. Added/removed planes and changed fetch demand can also use
the wrong data. The upstream change selects the checked CRTC's plane mask and
its new plane states, falling back to current state for unchanged planes.

The resulting complete performance source is byte-identical to current
upstreamf66469d9, Git blob9fa55904dba1a440a9e9ae22bf6fe0fedf79059c.
Clock calculation, OPPs, bandwidth limits/units, inefficiency factors, display
modes, firmware and existing refusal/recovery policy remain unchanged. The
full-width mode-clock request observed in the trace is an unclamped request,
not proof of an actual clock or a reason to lower the clock floor.

Source comparisons include exact Uke display44275c40, OnePlus same-SoC
modules1138e00f, Linux7.3.1/79a90760 and current upstreamf66469d9. OEM SDE obtains
votes through its vendor CRTC properties and has different policy ownership;
no vendor clock/OPP or board value is copied. The upstream active history is
the direct applicable fix, not a guessed optimization. The native preparation
queue must retain every later cumulative feature and reject an unexpected
modified performance file rather than overwrite it.

The actual `_calc_bw`, clock helper and CRTC caller are executed against
synthetic old/new/update states, using the real Linux DRM iterator and fallback
function.8198 cases cover resume, additions/removals, changed demand, unchanged
plane fallback,64-bit totals, factor zero/120 and preservation of both states.
Four GCC/Clang ordinary/sanitizer modes require the original and wrong-factor
control to fail at the bandwidth assertion. A real AArch64 performance object
is compiled independently with `-Werror`. Compilation runs only in COPR.

This is a source/native-object contribution, not a full cumulative Image,
installed change or proof that the source defect caused the observed Uke
latency. Uke still requires a matched future unstable kernel and physical
resume/DPMS, normal/dual-display, valid bandwidth votes, frame continuity and
recovery checks. CDSP/NPU/MEMC, stable DSC and complete calibrated cameras and
protected audio remain separate open goals. No new userspace runtime is added.
