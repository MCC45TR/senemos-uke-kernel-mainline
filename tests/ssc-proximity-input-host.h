/* SPDX-License-Identifier: GPL-2.0-only */
#include "ssc-native-host.h"
#define device proximity_test_device
struct proximity_test_device { void *driver_data; struct device *parent; };
#define iio_dev proximity_test_iio_dev
struct proximity_test_iio_dev { struct device dev; };
struct input_handler { void *private; };
struct input_dev {
	const char *name, *phys;
	struct { unsigned int bustype; } id;
	struct device dev;
	void *driver_data;
	int (*open)(struct input_dev *);
	void (*close)(struct input_dev *);
	bool registered, opened, near;
};
#define BUS_HOST 0x19
#define EV_SW 5
#define SW_FRONT_PROXIMITY 11
#define READ_ONCE(x) (x)
#define dev_warn_ratelimited(...) ((void)0)
static unsigned int assertions;
#define CHECK(expr) do { assertions++; assert(expr); } while (0)
struct ssc_sensor;
struct ssc_controller;
static int ssc_start(struct ssc_sensor *);
static int ssc_stop(struct ssc_sensor *);
static void ssc_dual_feed_locked(struct ssc_sensor *);
static void ssc_proximity_feed_locked(struct ssc_sensor *);
static unsigned long wait_for_completion_timeout(struct completion *, unsigned long);
static int iio_push_to_buffers_with_ts(struct iio_dev *, void *, size_t, s64);
static s64 iio_get_time_ns(struct iio_dev *);
static struct input_dev *input_allocate_device(void);
static void input_free_device(struct input_dev *);
static int input_register_device(struct input_dev *);
static void input_unregister_device(struct input_dev *);
static void input_report_switch(struct input_dev *, unsigned int, int);
static void input_sync(struct input_dev *);
static void input_set_drvdata(struct input_dev *input, void *data) { input->driver_data = data; }
static void *input_get_drvdata(struct input_dev *input) { return input->driver_data; }
static void input_set_capability(struct input_dev *input, unsigned int type, unsigned int code)
{ assert(input && type == EV_SW && code == SW_FRONT_PROXIMITY); }
