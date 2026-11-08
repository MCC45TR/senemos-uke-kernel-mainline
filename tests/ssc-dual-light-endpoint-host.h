/* SPDX-License-Identifier: GPL-2.0-only */
#include "ssc-native-host.h"
#define iio_dev endpoint_test_iio_dev
#define iio_chan_spec endpoint_test_iio_chan_spec
struct endpoint_test_iio_dev { void *private; bool direct, busy; unsigned int index; };
struct endpoint_test_iio_chan_spec { unsigned int address; };
struct device_node;
#define device endpoint_test_device
struct endpoint_test_device { void *driver_data; struct device *parent; struct device_node *of_node; };
struct input_handler { void *private; bool passive_observer; };
struct input_dev { struct device dev; unsigned long sw[1]; spinlock_t event_lock; };
struct input_handle { struct input_dev *dev; struct input_handler *handler; const char *name; };
struct input_device_id { unsigned long unused; };
#define EV_SW 5
#define SW_LID 0
#define BIT(n) (1U << (n))
#define U64_MAX UINT64_MAX
#define IIO_CHAN_INFO_RAW 0
#define IIO_CHAN_INFO_SCALE 2
#define IIO_VAL_INT_64 6
#define spin_lock(lock) do { assert(!*(lock)); *(lock)=1; } while(0)
#define spin_unlock(lock) do { assert(*(lock)==1); *(lock)=0; } while(0)
static bool test_bit(unsigned int bit, const unsigned long *words)
{ return !!(*words & (1UL << bit)); }
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
{ assert(iio->direct); iio->direct = false; }
static void iio_val_s64_decompose(s64 value, int *low, int *high)
{ *low = (u32)(u64)value; *high = (u32)((u64)value >> 32); }
struct ssc_sensor;
struct ssc_controller;
static int ssc_start(struct ssc_sensor *s);
static int ssc_stop(struct ssc_sensor *s);
static unsigned long wait_for_completion_timeout(struct completion *, unsigned long);
static int iio_push_to_buffers_with_ts(struct iio_dev *, void *, size_t, s64);
static s64 iio_get_time_ns(struct iio_dev *);
static int iio_device_register(struct iio_dev *);
static void ssc_dual_feed_locked(struct ssc_sensor *s);
static void ssc_dual_lid_locked(struct ssc_controller *c, bool known, bool closed);
static void ssc_dual_lid_start(struct input_handle *handle);
static int input_register_handle(struct input_handle *handle);
static void input_unregister_handle(struct input_handle *handle);
static int input_open_device(struct input_handle *handle);
static void input_close_device(struct input_handle *handle);
#define dev_get_drvdata endpoint_dev_get_drvdata
static void *endpoint_dev_get_drvdata(struct device *dev) { return dev->driver_data; }
static void cancel_work_sync(struct work_struct *work);
static void ssc_close_client(struct ssc_controller *c);
static void qmi_handle_release(struct qmi_handle *qmi);
static void input_unregister_handler(struct input_handler *handler);
static void iio_device_unregister(struct iio_dev *iio);
static void destroy_workqueue(struct workqueue_struct *queue);
