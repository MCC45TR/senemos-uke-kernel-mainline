/* SPDX-License-Identifier: GPL-2.0-only OR MIT */
/* Quaternion projection only; firmware owns fusion and calibration.
 * ENU XYZW semantics: Qualcomm sensinghub329551963bcc063f6a89f6cbca259c5b5c9c4e0b.
 * The projected device Y axis yields clockwise magnetic heading from north.
 * CORDIC vectoring uses generated atan(2^-i) microdegree constants; no FPU.
 */
#ifndef UKE_SSC_HEADING_H
#define UKE_SSC_HEADING_H
#include <linux/errno.h>
#include <linux/types.h>

static inline int uke_ssc_heading_microdegrees(const s64 q[4], s32 *heading)
{
 static const s32 angle[] = { 45000000, 26565051, 14036243, 7125016, 3576334, 1789911, 895174, 447614, 223811, 111906, 55953, 27976, 13988, 6994, 3497, 1749, 874, 437, 219, 109, 55, 27, 14, 7, 3, 2, 1 };
 s64 norm = 0, x, y, prior_x, divisor;
 s64 result = 0;
 unsigned int i;

 if (!q || !heading)
  return -EINVAL;
 for (i = 0; i < 4; i++) {
  if (q[i] < -1000000 || q[i] > 1000000)
   return -ERANGE;
  norm += q[i] * q[i];
 }
 /* Refuse malformed unit quaternions without changing the raw stream.
  * Homogeneous products retain a small valid quantization/scale error.
  */
 if (norm < 980000000000LL || norm > 1020000000000LL)
  return -ERANGE;
 x = norm - 2 * (q[0] * q[0] + q[2] * q[2]);
 y = 2 * (q[0] * q[1] - q[2] * q[3]);
 /* Near vertical, the device Y axis has no usable horizontal bearing.
  * Compare components to avoid squaring the scaled products (overflow).
  */
 if (x > -norm / 1000 && x < norm / 1000 &&
     y > -norm / 1000 && y < norm / 1000)
  return -ENODATA;
 if (x < 0) {
  x = -x;
  y = -y;
  result = 180000000;
 }
 for (i = 0; i < sizeof(angle) / sizeof(angle[0]); i++) {
  if (!y)
   break;
  prior_x = x;
  divisor = 1LL << i;
  if (y > 0) {
   x += y / divisor;
   y -= prior_x / divisor;
   result += angle[i];
  } else {
   x -= y / divisor;
   y += prior_x / divisor;
   result -= angle[i];
  }
 }
 result %= 360000000;
 if (result < 0)
  result += 360000000;
 *heading = result;
 return 0;
}
#endif
