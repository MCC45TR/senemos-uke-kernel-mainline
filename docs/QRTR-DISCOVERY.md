# Uke QRTR startup discovery

22 October 2026 Linux 7.3 source adaptation: signed 7.3 already contains the
global HELLO worker and MHI resume API. Its candidate keeps that initial
handshake, removes the `hello_sent` packet-drop gate, uses the same bounded
retry/teardown worker and requests Uke SMD HELLO after publication. It retains
7.3's name-server response policy, rather than restoring the older responses
described for 7.2 below. Actual-source host fault fixtures passed on this
adaptation; full source preparation, AArch64 and device gates remain separate.

22 October 2026. POCO Pad X1, Fedora Rawhide AArch64, kernel 7.2.12-16.
After one reboot, ADSP was running and its SMD IPCRTR channel was bound, but
QRTR advertised only the local locator and WPSS services. Battery sysfs reads
returned `EAGAIN`; UPower showed 0%, and SensorProxy could not find SSC.
After a bounded ADSP IPCRTR rediscovery diagnostic, ADSP services, battery
telemetry and SSC returned. This establishes the failed transport layer and
a recovery observation; it does not prove the precise startup race.

Release 7.2.12-17 adds an explicit HELLO request for Uke SMD endpoints after
their receive context is published. The worker waits for the name server and
retries allocation failure or transient transport backpressure. Endpoint
removal cancels work before releasing its node. The existing name-server
HELLO responses, broadcasts and ordinary packet flow remain in use.

The worker derives from upstream commit
[`544d85de4dc2`](https://github.com/torvalds/linux/commit/544d85de4dc22c01badfd8cefa59829ce35c4858),
by Chris Lew, Deepak Kumar Singh and Pranav Mahesh Phansalkar. Exact comparison
used the pinned Peridot source `2ed9eadbecae21ef51134e556951e7305ba65f88`,
Uke OEM kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd`, and the prepared
project 7.2.12 source. This changes a shared QRTR protocol, not board wiring.

The full upstream HELLO gate is not backported. Igor Opaniuk's
[19 October follow-up](https://lists.openwall.net/netdev/2026/10/19/242)
reports permanent control-packet loss behind that gate. The independent
[name-server continuation fix](https://lists.openwall.net/netdev/2026/10/19/240)
is included: one failed announcement must not suppress later servers or
pending lookup notifications. These October changes were proposals at review;
their reported reference-board tests are not Uke qualification.

Host tests compile the actual worker, SMD probe and affected name-server
functions with injected missing readiness, allocation and send failures.
They verify receive-context publication, foreign-board refusal, teardown,
continued announcements and pending lookup notification. ASan/UBSan and
three full AArch64 translation units with Clang 23.1.3 and `-Werror` passed.
No new target daemon, startup sleep, calibration, GPIO or charger policy is
introduced.

The candidate still requires a signed COPR build, matched DNF installation,
recoverable reboot and repeated physical startup/resume observations. Preserve
the accepted rollback until battery, SSC, WLAN, Bluetooth and touch start
without manual endpoint rebinding. A single successful boot does not measure
the failure rate or establish power-loss recovery.
