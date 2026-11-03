# Native touch recovery candidate

3 November 2026. A transient frame-transfer error in the1011 native driver
permanently latches fault. Its queued firmware worker then rejects its own
operation, and later panel/PM restoration does not clear the latch.

This candidate permits one complete verified firmware reload after a frame
I/O error in each powered lifecycle. A repeated error latches again. A new
panel-ready generation or nonretained PM resume re-arms recovery. Existing
epoch fencing, IRQ draining, image verification and calibration reset remain.
The current firmware, board configuration, gesture protocol and refresh modes
are unchanged. The existing input_stats prefix is retained, with additional
value-free I/O/recovery and fault/panel/suspend/IRQ fields.

The extended actual-production fixture checks recovery, exhaustion, lifecycle
re-arm and off/suspend/remove fencing, retaining the existing100transfer
races. The COPR recipe retains exact1011 input and requires an original-source
failure, corrected normal/sanitized checks and the full kernel/package gates.
Native results are pending; no candidate kernel is installed. Physical
recurrence and the separate gesture-entry timeout remain open.
