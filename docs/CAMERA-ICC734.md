# Camera HF interconnect admission

17 November 2026. Source comparison only. Accepted full8/B is unchanged;
no new QoS register, RPMh vote or camera path is activated.

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
The native Linux 7.3.4 setup enables clocks but has no equivalent bandwidth
proxy. A successful clock call alone is therefore insufficient evidence for a
new camera-port access. An uncertain partial transition also needs explicit
ownership and failure handling rather than an assumed rollback.

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

A qualified implementation must establish the exact HLOS proxy and register
ownership, preserve unrelated consumer votes, propagate the first real failure,
bound all accesses, and retain necessary references after uncertain errors.
Normal idle must release camera-owned demand without polling or narrowing a
shared provider's capabilities. Actual callback/fault tests and ARM64 objects
precede a cumulative full kernel and the aggregate DT dependency.

The OEM `cliffs.c`, `icc-rpmh.c`, native Linux7.3.4 `icc-rpmh.c` and
`bcm-voter.h` are the primary source inputs. Original Linux Foundation and
Qualcomm attribution and licenses apply. The source comparison neither admits
fitted sensor wiring nor establishes a physical frame, private read-only
calibration, rear focus or full OEM functionality.
