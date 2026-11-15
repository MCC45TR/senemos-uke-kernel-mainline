# Quaternion buffer alignment

10 November 2026. Actual full15 boots and registers three quaternion kinds.
A game_rv direct XYZW read succeeds; rotv and geomag_rv direct reads time out.
Those two sample/metadata paths remain unresolved. The initial finite reader
also incorrectly requested40-byte buffer records and is corrected separately.

Pinned Linux7.3.3 industrialio-buffer.c computes a repeat4 s64 element as32bytes,
places the timestamp at32 and rounds the total scan to the largest alignment:
64bytes. Full15 reserved56bytes at three sample-publication sites. The bounded
timestamp helper refuses that undersized buffer, so buffered quaternion data is
not accepted. No out-of-bounds access is inferred or required for this diagnosis.

Reserve64 zero-initialized bytes at all three publication sites. The six-value
sample capacity, wire decoder, direct snapshot, coordinates, metadata/status,
ownership and STOP paths remain unchanged. Scalar/XYZ/gravity scans retain
their actual IIO sizes. Tail padding is explicitly checked for zero bytes.

The test extracts the real pinned upstream scan-sizing functions alongside
the real driver callbacks rather than assuming a packed four-value record.
It rejects the previous56-byte producer and retains the earlier quaternion,
legacy64 and source-inverse controls. This is a source candidate until actual
COPR callback/ARM64, full/RPM and fitted-device64-byte readback are accepted.
It does not solve or qualify the separate rotv/geomag timeouts, magnetic heading,
physical frames, calibration, power or suspend behavior. Existing providers and
protected gain223 remain; no runtime RPM, service or poller is added.
