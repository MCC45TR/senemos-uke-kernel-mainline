# Native magnetic heading for the standard IIO consumer

10 November 2026. This candidate adds a derived IIO_ROT channel with modifier
NORTH_MAGN_TILT_COMP over the declared ROTV firmware quaternion. Its independent
IIO device uses signed32-bit microdegrees,scale10^-6 and a64-bit timestamp.
All original quaternion scan indices,repeat4 layout and raw interfaces stay.
GameRV has no magnetic reference and never supplies this endpoint. Geomagnetic
RV is not selected as an undocumented fallback.

The firmware continues to own fusion and calibration. Bounded integer products
project its ENU quaternion's device Y axis onto the horizontal plane; CORDIC
vectoring converts the projection to clockwise degrees from magnetic north.
The mathematical atan constants are generated,not copied from libssc. No FPU,
normalization of the original raw stream,second mount transform,true-north
claim,private calibration or new provider thread is introduced. Components,
unit norm and a nearly vertical projection are checked; failures preserve the
caller output and never publish a false zero. The existing firmware reliability,
API/metadata/generation and restart/suspend gates remain.

Raw direct,raw buffered and heading direct/buffered consumers hold distinct
bits on the same SUID. Joining never replaces an active request; only the last
owner stops it. The existing serialized control worker and indication callback
handle lifecycle. Heading uses a zero-initialized16-byte scan,with timestamp at8.
No polling timer,daemon,runtime RPM or DT desktop policy is added. The derived
view comes only from an existing declared ROTV child,after its metadata admission.

Primary contracts: Qualcomm sensinghub329551963bcc063f6a89f6cbca259c5b5c9c4e0b,
apis/proto/sns_rotv.proto (BSD-3-Clause-Clear); Linux7.3.3
 d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd,Documentation/ABI/testing/sysfs-bus-iio,
include/uapi/linux/iio/types.h and drivers/iio/magnetometer/hid-sensor-magn-3d.c
(GPL-2.0-only;Intel2012) provide the ABI,not Uke hardware configuration. Android
frameworks/base22626107841e928d472e8258c0d2cefccf9c9b81,
core/java/android/hardware/SensorManager.java (Apache-2.0;AOSP2008),
getOrientation/getRotationMatrixFromVector documents the standard
quaternion/azimuth relationship; this implementation is independently written
integer algebra. The existing pinned Uke OEM/SSC donor inventory is board/protocol
evidence; no same-SoC driver proving fitted heading accuracy was established.

Native tests compare the actual integer function with independent libm geometry
across sign,tilt,scale and wrap cases,and exercise actual shared-owner/read/buffer
callbacks with fake providers. Actual AArch64 object compilation remains separate
from fitted-device checks. The current device's ROTV/geomag samples fail reliability;
this candidate does not bypass that gate or claim to fix magnetic calibration.
Original SensorProxy parity still requires actual heading/frame/unit/power and
restart/suspend comparison plus supported DNF/recovery. Keep existing providers
until those pass. Physical heading,calibration and complete proxy parity remain
unaccepted even if the native proof succeeds.
