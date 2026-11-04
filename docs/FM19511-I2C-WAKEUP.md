# FM19511 wake ownership on Linux 7.3.1

4 November 2026. POCO Pad X1 running 7.3.1-7200-unstable reports FM19511
probe error -17 and exposes no tag character device. Its exact I2C node has
the wakeup-source property. This source correction is awaiting native COPR
qualification and a separate device trial.

Linux 7.3.1 i2c-core-of.c maps that property to I2C_CLIENT_WAKE.
i2c_device_probe() then initializes the wake source and normal or dedicated
wake IRQ before calling the device driver. The former FM19511 probe repeated
both operations. device_wakeup_attach() returns EEXIST when a source already
exists; the probe consequently unwinds before misc_register(). The former
remove/error paths also released resources owned by the I2C core.

The driver now leaves wake-source and wake-IRQ setup and cleanup with the
I2C core. Its event reporting, suspend/resume callbacks, bounded memory ABI,
volatile configuration, power requirements and EEPROM write refusal retain
their existing behavior. This change grants no general NFC-reader capability.

The remote regression extracts the actual Linux wake functions, I2C setup
block and former/corrected FM19511 probe/remove callbacks. The former probe
must reproduce EEXIST with wake enabled and succeed in the property-absent
control. The candidate must preserve shared and dedicated wake-IRQ ownership,
survive allocation/configuration/IRQ/misc/voltage refusals and complete repeated
bind/remove lifetimes. Hardware effects are mocked. Native objects and signed
RPMs require separate checks; these fixtures establish no physical RF wake.

Primary contracts:

- [I2C core](https://github.com/gregkh/linux/blob/v7.3.1/drivers/i2c/i2c-core-base.c)
- [OF wake flag](https://github.com/gregkh/linux/blob/v7.3.1/drivers/i2c/i2c-core-of.c)
- [Wake-source lifetime](https://github.com/gregkh/linux/blob/v7.3.1/drivers/base/power/wakeup.c)
- [Wake-IRQ lifetime](https://github.com/gregkh/linux/blob/v7.3.1/drivers/base/power/wakeirq.c)

Exact Uke wiring remains the MiCode uke-v-oss DT at
94c84aeb9e517dbde546fc732033c184094c8e57, with FM19511 at I2C address 0x57
and TLMM GPIO 170. No donor electrical values or firmware are changed. The existing
tag code retains its Uke OEM attribution. A board donor is unnecessary for
the bus-core lifetime contract; real interrupt and suspend behavior still
require the fitted device.

Continue qualification in the unstable kernel family. RTC calendar persistence,
both complete camera pipelines, private fitted calibration and rear autofocus
remain independent open requirements.

The composition producer pins the exact qualified RTC7300, HSIC7600 and
CDSP/pogo7603 source RPMs, plus the failed Android-network8200 prototype, by
complete, header and payload digest. The three delivery parents must succeed.
8200 failed effective-config admission and is a research reference only. Its
missing NETFILTER_XTABLES_LEGACY and IPv4/IPv6 IPTABLES_LEGACY prerequisites
are corrected explicitly, preserving its original input for attribution.
The source worker resolves actual upstream Kconfig and requires every requested
network setting before publishing; full native object checks remain required.
The composition retains all
unrelated source files, original source snapshots, camera stage0 and boot
policy. Camera stage1 in the separate8101 diagnostic remains a separate trial;
this composition does not grant physical camera acceptance.

The Android network input differs only in the reviewed routing/filter settings;
the combined input adds the pogo HID module. COPR independently resolves the
original CDSP input and the exact network input on the final prepared sources.
The original CDSP configuration assertion must pass on its resolved reference.
Every effective setting in the combined kernel must then match the independently
resolved network reference, except that HID module. Real routing/filter objects,
existing firewall negative fixtures, all retained device checks and the actual
NFC object remain required. This replaces a stale single-parent configuration
comparison with explicit coverage of both source inputs and the complete final
configuration; runtime networking and physical device behavior remain unproved.

The legacy-table dependency is specified in Linux7.3.1
[generic Netfilter Kconfig](https://github.com/gregkh/linux/blob/v7.3.1/net/netfilter/Kconfig),
[IPv4 Kconfig](https://github.com/gregkh/linux/blob/v7.3.1/net/ipv4/netfilter/Kconfig)
and [IPv6 Kconfig](https://github.com/gregkh/linux/blob/v7.3.1/net/ipv6/netfilter/Kconfig).
The current7200/7300 configuration disables PREEMPT_RT, satisfying the generic
legacy-table constraint. No preemption policy, DT, firmware or electrical
parameter is changed by this correction.
