# Native SSC shared stream ownership

8 November 2026. Source-only preparation for the combined light endpoint.
The preceding reducer is qualified by COPR11285557/source25. This change must
qualify actual driver callbacks and its real AArch64 SSC composite; it does not
register a combined IIO device or subscribe to Hall input. No full kernel,
provider retirement, brightness policy or physical functionality is admitted.

The existing driver has one request per SUID in its SSC client. A future paired
consumer must not restart or disable a raw reader's active stream. Conversely,
raw direct reads or buffer shutdown must not stop the pair. The controller's
existing control mutex serializes three demand owners: direct, buffer and pair.
Only the first demand starts an inactive stream; only the last release stops
it. Duplicate/invalid leases are rejected. A failed acquisition drops only its
new owner. Namespace invalidation retains outstanding demand, while clearing
all existing sample/metadata validity through the unchanged recovery paths.
The raw buffer's existing fault latch suppresses its own automatic restart;
it does not erase another consumer's demand.

Direct reads can use a valid sample from a currently acknowledged, continuously
active on-change stream. They cannot accept disconnected, unready, errored,
inactive or zero-timestamp data. Otherwise the existing bounded completion
wait applies. A raw buffer joining an unchanged live stream receives one valid
current sample; an initial sample already published during ACK is not repeated.
All SSC command encoding, API/name/status admission, early indication/ACK order,
fault shutdown, calibration ownership, units, DT and config remain unchanged.

The planned pair owner is exercised at the controlled provider boundary; no
production combined consumer exists yet. Restart epochs, front freshness after
reopening, shared-owner interactions with Hall transitions, IIO registration
and suspend/remove ordering still need actual endpoint integration and tests.
Original SensorProxy compatibility and physical comfort remain separate work.

The standalone tests compile actual owner, raw and buffer callbacks. They cover
all36 acquisition/release permutations, duplicate/invalid leases, namespace and
metadata refusal, failed starts, fault-latched demand, admitted cached samples,
wait/reset/error cleanup, and first-sample versus buffer-join publication.
Five deliberately incorrect implementations per compiler must compile and fail
behavioral assertions. Every original QMI/metadata/ACK assertion is rerun against
the postimage using an extractor-only adapter; original C assertions stay exact.
The complete driver inverse must restore source SHA256
`c7a271fb57d329cdbc31f0d8876af4c4ef95ee16e880137e7fd003a8f45630fd`.

Comparison inputs are the current Uke native SSC source and existing donor
review in `manifests/dual-light-events-20261108.json`, including original
SensorProxy3.9 and pinned Linux7.3.3 IIO lifetime/units interfaces. This is new
GPL-2.0-only project code; no GPL-3.0 proxy implementation or donor board data
is copied. No matching upstream multi-consumer Uke SSC client was established
by that review. The inactive ownership scaffold is not a proof that a complete
OSS-equivalent brightness path, Hall boot or power behavior exists.
