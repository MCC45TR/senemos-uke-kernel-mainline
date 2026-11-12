# SSC streaming buffer freshness

The accepted24 SSC driver can replay a cached sample when a second consumer
joins a running stream. The replay uses the joining consumer's current host
timestamp. That behavior is useful for an unchanged on-change state, but makes
an old gravity or quaternion report appear newly acquired.

The additional kernel rule limits this replay to the already admitted
on-change stream type1. Streaming type0 waits for its next actual report.
There is no timer, poll, additional sensor request, raw ABI/rate change or
second IIO owner. Early reports received before the enable ACK are still
published once and never duplicated by the replay path. Shared demand and
final-owner stop behavior are unchanged. Raw direct reads retain their
existing cache semantics; this change concerns buffered streaming consumers.

The exact cumulative SSC postimage is
f7c689e893e8696dcf093cf859dbb07dfc6b31b5332ce4108a19be13252efca1.
Only the buffer-enable replay condition and its explanation change. The
postimage is
f86be00568afe4fa28acb570742f374f0b0283e2f4fe2b73d97b2de777c892d8.
Reversing the patch must reproduce the complete original driver byte-for-byte.

The pinned Qualcomm sensinghub protocol and the existing native attribute
decoder distinguish streaming0 and on-change1. The unchanged Linux7.3.3 IIO
timestamp path uses the device's selected host clock. This does not convert
SSC hardware ticks into host time or establish a physical sample's age before
its report reached the host. Cached on-change state still uses subscription
time; consumers needing acquisition age must not treat that as a new report.

Native107 exercises the actual publish/enable/disable callbacks for all12
datatypes with GCC/Clang ordinary and address/undefined sanitizers. It checks
streaming joins, unchanged on-change replay, early-ACK deduplication, values,
scan padding, duplicate enables, failures and release. An actual-body mutation
restoring the former unconditional cache replay must fail. The complete
accepted24 preparation and complete CAMCC checks remain; quaternion layout, heading
lifecycle, proximity ABI and real AArch64 SSC objects are checked separately.

The source is prepared, not yet natively qualified or delivered. Gravity's
physical frame/mount transform remains unadmitted. This change does not justify
copying the accelerometer's matrix or opening a new raw-device permission.
The existing Control package remains the owner of any required session bridge;
keyboard inclination policy remains in its userspace client.

Full24 applies its later SSC layers during the source portion of build,
after prep. The native check reproduces that exact final SSC postimage from
the prepared c7a271fb driver and15 retained patches before applying the new
condition. Protocol and Makefile bytes remain unchanged. This assembly is
specific to the source check; full delivery must retain the complete ordered
source stages and place the new change after proximity ABI admission.
