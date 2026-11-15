# Physical initial state for the Uke lid

7 November 2026. The running 7.3.3-4 kernel still times out waiting for the
initial Hall event pair. Extending the existing 30-second retry does not
address firmware that leaves the pair unknown until the cover moves.

With the operator holding the cover stationary, read-only observations show
TLMM GPIO99 low when closed and high when open. Both observations show input,
GPIO function 0, a pull-up and 2 mA drive configuration. Linux pinctrl reports
the line unclaimed. GPIO100 remains high in both cases and is not qualified
as a lid input. These observations followed cover movement; they do not
establish recognition during boot with a continuously closed cover.

## Source comparison

- Exact Uke OEM DT `MiCode/kernel_devicetree`,
  `94c84aeb9e517dbde546fc732033c184094c8e57`,
  `qcom/uke-sm8635.dtsi`, identifies `hall_pin` as TLMM99 active-low for
  the lid and retains the two `mi_hall_lid` event bits. The file has no clear
  SPDX identifier; only the board connection is independently represented.
- The previously inspected OEM `xiaomi_hall.ko` uses a physical GPIO read in
  its handler. This is static reference evidence, not a module loaded or
  executed on the tablet. Its raw register or binary implementation is not
  copied into the candidate.
- Same-SoC OnePlus SMP2P
  `fc892483f1d61f245924681eb5abd563564d9cba`,
  `drivers/soc/qcom/smp2p.c`, is GPL-2.0-only with Sony, Linux Foundation
  and Qualcomm notices. It provides the transport comparison, not Uke's
  physical cover wiring or an interchangeable firmware initial-state fix.
- Linux 7.3.3 `d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`,
  `drivers/pinctrl/qcom/pinctrl-msm.c` and the GPIO consumer API, provides
  descriptor acquisition, direction checking and logical active-low reads.
  Existing Sony/Linux Foundation attribution and GPL-2.0-only code remain.
  The pinned upstream/linux-next SMP2P comparison in `HALL-STARTUP.md`
  supplies no interchangeable board-level initial sampler.

## Candidate behavior

The optional standard `state-gpios` property describes the physical closed
level. Uke's early DT conversion accepts only the measured existing TLMM99
active-low connection. Missing optional wiring retains the remote-only
behavior; malformed wiring is rejected. The tablet-mode input, remote IRQ
graph, normal open/close reporting and wake preference are preserved.

Only an initial or resume acquisition whose remote pair is unavailable uses
the physical sampler. It acquires the descriptor with `GPIOD_ASIS`, requires
an existing input direction, reads twice across a 1–2 ms interval and releases
the descriptor before reporting. Errors and unstable samples retain the
existing bounded retry. Normal IRQ handling never calls the physical sampler;
initial resynchronization cannot generate a wake event.

`GPIOD_ASIS` avoids requesting a new direction or output value. It does not
mean the GPIO provider performs no register operation: MSM's normal GPIO
request selects GPIO muxing. The measured line is already in that mode.
Compare direction, mux, pull, drive, ownership release and normal remote
events during device qualification. Do not claim unchanged firmware ownership
or interrupt behavior solely from the callback fixture.

The additive patch is authenticated against the exact cumulative driver.
An inverse source check preserves every old byte outside the initial-read
extension. Legacy checks consume that authenticated predecessor; the new
production callbacks run all legacy assertions with the optional property
absent, then exercise physical polarity, supplier errors, direction errors,
unstable samples, release, retry, resume, timeout and IRQ separation.
Required mutants reintroduce raw polarity, lost release, ignored direction,
lost debounce and physical reads on normal IRQs. Independent DT tests retain
the original fixtures and reject incorrect wiring. Actual AArch64 driver and
early-DT objects must also pass before a full candidate.

These tests are not physical acceptance. Deliver the complete cumulative
unstable kernel through COPR and DNF into the inactive slot. Boot with the
cover continuously closed, compare native `SW_LID`, logind, UPower, display
power and GPIO state before any cover motion, then verify open/close and
resume/wake. Keep the prior kernel/modules, automatic staging and local
rollback preference. Gain243 and automatic brightness remain separate goals.
