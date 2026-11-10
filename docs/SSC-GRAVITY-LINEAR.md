# Native gravity and linear acceleration

10 November 2026. This source layer extends the existing native SSC consumer
with one explicitly declared `gravity` firmware endpoint. The standard event
contains gravity XYZ followed by linear acceleration XYZ, all in m/s². One
six-channel IIO device preserves the acquisition relationship and uses the
existing demand/shared-owner, generation, ordering and suspend/restart machinery.
It adds no resident task, independent poller or AP-side fusion algorithm.

The first triplet uses IIO_GRAVITY. The second uses IIO_ACCEL with the `linear`
channel suffix, so original desktop rules requiring physical `in_accel_x_raw`
do not mistake the new fusion output for the retained accelerometer. Values
use signed64-bit micro-units with scale10^-6. Both triplets and the host receipt
timestamp share a scan; firmware tick ordering remains separate. No guessed
mount matrix or second coordinate transform is applied.

The exact datatype/API and streaming metadata are required. Only this declared
fusion kind may advertise physical=false, alongside the separately qualified
rear-ALS exception; other sensors retain their physical/availability/HLOS/rate
gates. Zero/unreliable status, wrong event, incorrect field count and nonfinite
values are refused. The six-channel bounded buffers also retain correct scalar
and XYZ timestamp placement, verified using actual callbacks and independent
wire values. Driver, early DT and binding changes have complete preimage inverses.

Primary sources inspected unchanged:

- Qualcomm sensinghub329551963bcc063f6a89f6cbca259c5b5c9c4e0b,
  `apis/proto/sns_gravity.proto`, BSD-3-Clause-Clear, SHA256
  506af7b4134433f6123852a31c01daca9768027db1345d8ecad2a4f63d9b2028:
  six values, m/s², `sns_std_sensor_event`, streaming configuration.
- Linux7.3.3 d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd, GPL-2.0,
  `include/uapi/linux/iio/types.h`, IIO_GRAVITY/IIO_ACCEL, and
  `include/linux/iio/buffer.h`, timestamp placement and buffer-size admission.
- Uke OEM sensor registry/HAL evidence remains the pinned board source from
  the donor inventory; firmware-facing standard metadata, not a hardcoded
  fitted chip, determines runtime admission. No applicable same-SoC native
  implementation proving the fitted gravity endpoint is established by that
  inventory. No other-board calibration or GPL3 libssc code is copied.

The existing eight sensor descriptions, raw channels, Hall/dual ALS/proximity
input and all full13 features remain. This is not CCT/flicker support, compass
parity, optical accuracy or proof that the fitted firmware exposes the new
endpoint. SAR availability, quaternion/heading conventions, vendor vector units
and original Fedora SensorProxy/provider transitions remain separate tasks.
A successful COPR callback/schema/ARM64 proof is not tablet acceptance; native
full delivery, actual six-channel data, axes/units, power and repeated resource
restart/suspend tests remain required before retiring any userspace provider.
