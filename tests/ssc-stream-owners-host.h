/* SPDX-License-Identifier: GPL-2.0-only */
#include "ssc-native-host.h"
/* Keep the original native-QMI fixture untouched. Only these two IIO types
 * need their real callback-facing fields in this independent provider fixture.
 */
#define iio_dev owner_test_iio_dev
#define iio_chan_spec owner_test_iio_chan_spec
struct owner_test_iio_dev { void *private; bool direct, busy; };
struct owner_test_iio_chan_spec { unsigned int address; };
#define IIO_CHAN_INFO_RAW 0
#define IIO_CHAN_INFO_SCALE 2
#define IIO_VAL_INT_64 6
static unsigned int assertions;
#define CHECK(expr) do { assertions++; assert(expr); } while (0)
static void *iio_priv(struct iio_dev *iio) { return iio->private; }
static bool iio_device_claim_direct(struct iio_dev *iio)
{
	assert(!iio->direct);
	if (iio->busy)
		return false;
	iio->direct = true;
	return true;
}
static void iio_device_release_direct(struct iio_dev *iio)
{
	assert(iio->direct);
	iio->direct = false;
}
static void iio_val_s64_decompose(s64 value, int *low, int *high)
{
	*low = (u32)(u64)value;
	*high = (u32)((u64)value >> 32);
}
struct ssc_sensor;
static int ssc_start(struct ssc_sensor *s);
static int ssc_stop(struct ssc_sensor *s);
static unsigned long wait_for_completion_timeout(struct completion *, unsigned long);
static int iio_push_to_buffers_with_ts(struct iio_dev *, void *, size_t, s64);
static s64 iio_get_time_ns(struct iio_dev *);
