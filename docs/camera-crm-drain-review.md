# Camera CRM status validation after IRQ drain

5 November 2026. This source review extends the qualified aacc2b9 transport
lifecycle without activating the CAMCC provider or changing the running kernel.

The current idle path validates owned votes/status, disables owned IRQ delivery,
marks the transport quiesced and waits for CPU handlers. A callback in that state
deliberately performs no MMIO. An owned status first visible during that wait
can therefore escape the earlier validation before idle or release returns.

Linux [synchronize_irq() documentation](https://www.kernel.org/doc/html/latest/core-api/genericirq.html#c.synchronize_irq)
defines handler synchronization; it does not replace a device-status check.
The exact Uke OEM5712080 CRM handler clears device status separately. The
existing source review pins the applicable OEM, shared-IP, upstream and active
CESTA comparisons. No donor implementation is imported by this proposal.

The proposed patch validates powered access and the complete owned idle state
after the first drain. Unexpected status preserves the first fault, IRQ and
mapping; it is neither acknowledged nor released. Already quiesced operations
retain their no-MMIO behavior, including clean release after power removal.
Inherited votes, firmware CRM enable, hardware voters and the provider guard
remain unchanged. Qualcomm/Linux Foundation attribution remains in the headers.

The native regression includes the retained actual-body fixture. Its IRQ-drain
hook introduces status on each owned PERF/BW resource for quiesce and release.
The exact original must fail at the required status assertion; the proposal must
pass all sixteen cases and every original transport/lifecycle case under GCC,
Clang and ASan/UBSan. This is an observable-state fault model, not proof that
such a hardware event caused the current camera refusal or desktop freezes.

COPR source-model results, a real AArch64 kernel object, complete CCF/runtime-PM
integration, cumulative kernel delivery and physical cameras/calibration/focus
remain separate gates. This review package carries text only and is not a
runtime installation. The camera coordinator retains the sole full-kernel queue.
