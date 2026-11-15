# Native SSC quaternion transport

10 November 2026. This source layer adds the standard firmware datatypes
rotv, game_rv and geomag_rv after the admitted full14 gravity layer. Firmware
performs fusion. The driver exposes each XYZW unit quaternion as one standard
IIO_ROT/IIO_MOD_QUATERNION channel with repeat4, signed64-bit micro-units and
scale10^-6, followed by a timestamp. It does not expose four unrelated scalar
rotation channels, normalize samples, rotate axes again or calculate heading.

Direct sysfs reads use one shared demand and one locked complete snapshot.
The existing scalar/XYZ/gravity64-bit representation, cached on-change behavior,
timeout, final-owner STOP and disconnect/error handling remain. Scale and raw
array lengths use the standard read_raw_multi interface. The exact datatype,
API, availability, stream/rate and generation checks remain; only declared
firmware fusion kinds join the existing logical rear-ALS exception to physical
metadata. Unreliable status, wrong dimensions/event, nonfinite values and
out-of-range unit components refuse. Component bounds do not prove physical
normalization or orientation accuracy.

The pinned public Qualcomm sensinghub revision
329551963bcc063f6a89f6cbca259c5b5c9c4e0b specifies unitless XYZW in
apis/proto/sns_rotv.proto, sns_game_rv.proto and sns_geomag_rv.proto
(BSD-3-Clause-Clear). ROTV and geomagnetic RV refer to ENU; game RV has an
unspecified reference frame and must not be advertised as magnetic north.
Linux7.3.3 d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd documents XYZW in
Documentation/ABI/testing/sysfs-bus-iio and defines read_raw_multi/repeat in
include/linux/iio/iio.h. drivers/iio/imu/bno055/bno055.c illustrates this ABI,
not fitted Uke hardware. Linux references are GPL-2.0; existing attribution
remains. No GPL3 libssc conversion algorithm or private registry/calibration
is copied. Exact file hashes are recorded in the source manifest.

The Uke OEM registry/HAL inventory remains board evidence, not permission to
transplant another board's matrix or calibration. No applicable same-SoC native
implementation proving these fitted endpoints was established by the pinned
donor inventory. Runtime discovery must establish actual availability and API.
DT declares firmware endpoints without new bus clients or a fitted chip claim.

Current status: source implementation only. No native build, full kernel,
device quaternion/axes/heading, power, restart/suspend or physical acceptance
is claimed. Original Fedora SensorProxy needs separate compass/orientation
parity; raw quaternions alone do not supply its tilt-compensated heading ABI.
Keep existing libssc, sensor proxy and DSP registry/file services until parity,
supported DNF transitions and old-kernel recovery are verified. No new runtime
RPM, daemon, independent poller or AP fusion algorithm is introduced.
