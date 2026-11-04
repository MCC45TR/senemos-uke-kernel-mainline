# Uke RTC counter and firmware offset admission

4 November 2026. POCO Pad X1, Fedora 46 AArch64, kernel 7.3.1-7200-unstable.
The candidate boots to userspace with rollback off, but RTC registration remains
deferred and the RTC synchronization service fails. This is not a healthy RTC
or full kernel qualification result.

The retained boot conversion unconditionally adds `qcom,uefi-rtc-info` to the
PMK8550 RTC node. Linux 7.3.1 `pm8xxx_rtc_probe_offset()` returns `-EPROBE_DEFER`
while that contract is requested and `efivar_is_available()` is false. The
observed boot has no EFI services, no RTC class device, and a bound QSEECOM
parent without a UEFI secure-application child. QSEECOM version 0x1402000 alone
does not establish the required variable provider. The driver registers the
child only after finding the already-loaded `qcom.tz.uefisecapp` application;
the absence of that child on a successfully bound parent indicates that its
lookup found no application. This is a source/runtime inference, not a new
firmware query or a secure-variable write.

The next unstable candidate preserves the read-only PMIC counter contract used
by the accepted baseline. Its FDT admission validates the exact Uke/SM7675 and
PMK resources and leaves the node unchanged. It refuses existing direct-write,
NVMEM or secure-offset properties rather than replacing an unknown contract.
The driver applies its UTC-calendar validity rule only when a secure offset is
actually in use. Counter-only reads retain the original epoch; offset updates
without a backend still return the upstream `-ENODEV`. No writable PMIC counter,
SDAM cell, foreign offset address, secure application or proprietary firmware
is introduced. Persistent system time continues using the existing synchronized
clock floor and NTP. Persistent RTC UTC remains an open feature.

Existing secure-offset code and failure/readback fixtures remain available for
a separately qualified provider. The new actual-driver fixture additionally
checks raw counter reads and write refusal without any EFI-variable call. The
actual libfdt fixture checks unchanged input bytes and conflicting contracts.
They execute in COPR before the full kernel build and again during the retained
kernel preparation. Build success does not prove RTC binding, wake alarms,
calendar persistence, complete cameras or rear autofocus on the tablet.

Primary comparisons:

- Xiaomi Uke kernel commit `5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
  `drivers/rtc/rtc-pm8xxx.c`: host counter writes require `allow-set-time`.
- Xiaomi Uke Device Tree commit `94c84aeb9e517dbde546fc732033c184094c8e57`:
  preserve the measured PMK resource and board wiring.
- [Linux 7.3.1 RTC driver](https://github.com/gregkh/linux/blob/v7.3.1/drivers/rtc/rtc-pm8xxx.c)
  and [QSEECOM client discovery](https://github.com/gregkh/linux/blob/v7.3.1/drivers/firmware/qcom/qcom_qseecom.c).
- The pinned Palawan/Peridot and same-SoC acquisition inventory was reviewed;
  its recorded local donor checkouts are absent in this workspace. No qualified
  Uke variable-provider implementation was established from those inputs, and
  no foreign board storage value is substituted.
