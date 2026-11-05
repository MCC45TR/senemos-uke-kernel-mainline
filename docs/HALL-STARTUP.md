# Initial Hall switch state

5 November 2026. The operator reports that a stationary closed magnetic cover
is missed after reboot until it is opened and closed. Running Uke kernel
`7.3.1-12204-unstable` exposes both standard Hall input devices. An unprivileged
snapshot reports logind lid-open; the simultaneous physical position and raw
SMEM/input state are unavailable. This is a candidate for an identified source
gap, not a measured diagnosis or a completed hardware fix.

The existing input driver samples the pair once after requesting its IRQs.
An absent entry, unknown `00`, or contradictory `11` leaves the initial input
state unchanged. There is no later startup read. If a valid stationary pair
appears without a delivered edge, the driver cannot recover until another
physical transition. Current SMP2P can also preserve the initial value as its
edge history; replaying unrelated remote interrupts is not an appropriate fix.

`0002-smp2p-switch-initial-state.patch` adds an immediate sample followed by
up to 119 retries at 250 ms intervals while the pair remains unavailable.
The first valid pair ends this startup work. Timeout leaves normal interrupts
active and emits one warning. Suspend cancels pending work; resume starts a
fresh bounded acquisition. Managed cancellation runs after IRQ release and
before the input device is released. A mutex serializes read/report operations.
Only a real valid open IRQ retains permission to generate a wake event.

No GPIO ownership, firmware, DT, userspace package, wake default, persistent
preference, kernel selection or boot state changes. If the fitted firmware
never publishes a valid stationary pair, this change cannot recover it.
That condition needs exact remote-firmware/protocol evidence before another
implementation is justified.

## Reference comparison

| Source | Exact revision and file | Relevant contract and limit |
| --- | --- | --- |
| [Uke OEM kernel](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/5712080a4b0c0b1a879e6d145c601c649ddaddfd) | `5712080a4b0c0b1a879e6d145c601c649ddaddfd`, `drivers/soc/qcom/smp2p.c` | Remote entry allocation, edge history and pending-IRQ handling. GPL-2.0-only; Sony Mobile/The Linux Foundation/Qualcomm Innovation Center notices. Android transport internals are not copied. |
| [Uke OEM DT](https://github.com/MiCode/kernel_devicetree/blob/94c84aeb9e517dbde546fc732033c184094c8e57/qcom/uke-sm8635.dtsi) | `94c84aeb9e517dbde546fc732033c184094c8e57`, `qcom/uke-sm8635.dtsi` | Exact `mi_hall_lid`/`mi_hall_table` paired entries and input codes. Board wiring already preserved by `uke-hall.h`; remote GPIO ownership remains unchanged. This OEM file has no SPDX header; no DT bytes are copied by this change. |
| [OnePlus SM7675](https://github.com/OnePlusOSS/android_kernel_oneplus_sm7675/blob/fc892483f1d61f245924681eb5abd563564d9cba/drivers/soc/qcom/smp2p.c) | `fc892483f1d61f245924681eb5abd563564d9cba`, same transport file | Same-SoC SMP2P pending IRQ and edge-history comparison, GPL-2.0-only with Sony Mobile/The Linux Foundation/Qualcomm Innovation Center notices. This is not Uke cover firmware or an interchangeable board driver. |
| [Upstream Linux](https://github.com/torvalds/linux/blob/05441d697f7f9a927264f4058cbbc6a03dfcac9d/drivers/soc/qcom/smp2p.c) | `05441d697f7f9a927264f4058cbbc6a03dfcac9d`, same transport file | Early-attach `start_in()` seeds `last_value`; `IRQCHIP_STATE_LINE_LEVEL` returns `-ENODEV` before an entry exists. GPL-2.0-only, original Sony Mobile/The Linux Foundation attribution retained. |
| Linux next | `ddfe51b0a0f5dc9e415cc2c8ad8db17532dd426b`, same transport file | Active integration queue comparison of initial matching, edge history and line-state query. Byte-identical to the inspected upstream file. No interchangeable Uke Hall consumer fix selected. |

The pinned 14 October donor inventory, 15 October MiCode survey and workspace
`DONOR-POLICY.md` were reviewed. Reference snapshots remain unchanged. No donor
scripts, GPIO acquisition or firmware programs are executed.

## Source qualification and integration

`packaging/native/copr-hall-startup-check.sh` retains the complete immutable
12204 source RPM and its original preparation, then applies the exact-hash
guarded driver patch. It executes production callbacks with GCC and Clang,
with and without address/undefined-behavior sanitizers. Assertions cover late
stationary closure without IRQ, initial open, provider errors, invalid pairs,
timeout, subsequent normal IRQs, wake permission, resume and cancellation.
Four deliberately broken callbacks must fail runtime assertions. The actual
AArch64 driver object must compile with the retained production configuration
and `-Werror`. Only text receipts and licenses are packaged.

For the following cumulative kernel, the coordinator can apply
`src/input/apply-smp2p-switch-startup.sh PREPARED_KERNEL` after the existing
selective-wake preparation, retain the patch and callback tests as build
inputs, and require the exact postimage hash in the final source audit.
The helper accepts an exact repeat and refuses an unexpected cumulative
driver. The earlier Hall/lid checks run before this delta; the new callback
fixture validates the changed reporting path. Do not replace the cumulative
profile with this contributor checkout.

Physical acceptance still requires a DNF-delivered cumulative unstable kernel:
boot with the cover continuously closed, compare read-only remote pair and
raw `EVIOCGSW` state against logind/UPower/output state before moving it,
then test a normal open/close, resume and lid-open wake. Record internal-only
and external-display cases separately. A passed object build does not qualify
these behaviors. Stable promotion and reboot remain coordinator operations.
