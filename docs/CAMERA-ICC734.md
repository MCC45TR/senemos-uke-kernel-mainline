# Camera HF interconnect admission

18 November 2026. Source34/COPR11343921 passed in 547 seconds. The signed
proof RPM has two trusted signatures. The layer is not installed on the tablet.
Accepted full10/A remains running, with accepted full8/B recovery preserved.
No new QoS register, RPMh vote or camera capture path is active on the tablet.

The exact Uke GPL kernel at `5712080a4b0c0b1a879e6d145c601c649ddaddfd`
defines a HLOS camera HF master with two 32-byte channels, QoS ports
0xa8000/0xa9000, priority zero and urgency forwarding. It links to the existing
HF memory-NoC slave. That master belongs to HLOS BCM MM1 with enable mask one;
the HF slave belongs to MM0. Separate camera-IFE voter aliases do not replace
this HLOS topology.

The cumulative native display/video provider already supplies the shared HF
route and an MM1 subset for video. It has no camera HF master. Adding another
provider or another MM1 object would duplicate existing ownership. The eventual
camera route must extend the existing nodes and BCM membership while preserving
display, video and every existing interconnect endpoint.

QoS access also needs its dependencies. The OEM `icc-rpmh.c` identifies HLOS
BCMs containing QoS nodes, temporarily supplies a minimum bandwidth vote,
then enables configuration clocks before programming their ports. It restores
the prior keepalive policy and withdraws the temporary vote after configuration.
The native Linux 7.3.4 setup has no explicit equivalent bandwidth proxy, but
its ICC core already installs INT_MAX initial requests before configuration.
Current upstream also deliberately retains that behavior for QoS providers.
This corrects the earlier inference that native startup has no bandwidth
dependency. A successful clock call alone still does not verify that dependency:
both the core node-add caller and the old RPMh set callback discard errors.

The OEM MM0 also requests an early keepalive. The native display source
explicitly records that the original field has no direct counterpart in its
baseline. A temporary proxy must account for inherited startup bandwidth and
the eventual handoff; simply restoring a boolean and committing zero could
withdraw a request still needed by another boot consumer. No replacement
request, permanent keepalive or release point is inferred here.

Two native error paths require separate review. `qcom_icc_set_qos()` discards
each register-update return value, while `qcom_icc_set()` discards the result of
the integer-returning BCM voter commit. The existing cumulative `qos_required`
flag propagates setup errors that reach it; it cannot detect errors discarded
inside those helpers. These are source findings, not observed Uke failures.

The candidate extends the existing MM1 with the exact HLOS camera HF master;
it adds no provider, second BCM, rate, temporary keepalive or register value.
Before required QoS configuration it recommits the existing BCM aggregates and
checks the result. It does not change requests, tags or inherited-vote policy.
The first register-update failure returns after balancing configuration clocks.
BCM initialization failures stop probe, and a failed auxiliary-data lookup no
longer publishes a valid-looking address cache that could hide a failed retry.

The COPR gate executes actual native initial-node, aggregation, set, BCM-init
and QoS functions against modeled register/transport/clock operations. Passing
coverage includes four compiler/sanitizer modes, all fifteen register failure
positions, commit/clock/auxiliary-data failures, 256 shared-video demand/idle
cycles per mode, two original-failure controls, four semantic mutants, exact
legacy display/video write traces and both real ARM64 driver objects.
The full probe is compiled, not
emulated; source checks verify its dependency and refusal ordering.

The OEM `cliffs.c`, `icc-rpmh.c`, native Linux7.3.4 `icc-rpmh.c` and
`bcm-voter.h` are the primary source inputs. Original Linux Foundation and
Qualcomm attribution and licenses apply. The source comparison neither admits
fitted sensor wiring nor establishes a physical frame, private read-only
calibration, rear focus or full OEM functionality. See the
[source manifest](../manifests/camera-icc-hf734-20261118.json) and
[signed qualification](../manifests/camera-icc-hf734-qualification-20261118.json).

Primary source links: [native initial requests](https://github.com/gregkh/linux/blob/v7.3.4/drivers/interconnect/core.c),
[current upstream QoS dependency](https://github.com/torvalds/linux/blob/666539eecdf4db623f5e3c3e55cf9f2dfad24aa4/drivers/interconnect/qcom/icc-rpmh.c),
and [exact Uke HLOS topology](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/blob/5712080a4b0c0b1a879e6d145c601c649ddaddfd/drivers/interconnect/qcom/cliffs.c).
