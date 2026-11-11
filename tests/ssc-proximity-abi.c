/* SPDX-License-Identifier: GPL-2.0-only OR MIT */
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#define SSC_SENSOR_COUNT 12
enum ssc_kind { SSC_ACCEL, SSC_PROXIMITY, SSC_LIGHT };
struct ssc_description { enum ssc_kind kind; };
struct ssc_sensor { bool declared; const struct ssc_description *description; };
struct ssc_controller { struct ssc_sensor sensor[SSC_SENSOR_COUNT]; };
struct iio_dev { struct ssc_sensor *priv; };
struct device { struct iio_dev *iio; };
struct device_attribute { int unused; };
#define dev_to_iio_dev(d) ((d)->iio)
#define iio_priv(i) (&(i)->priv)
#define sysfs_emit(buf, ...) snprintf((buf), 32, __VA_ARGS__)
#include "actual-proximity-abi.inc"
static unsigned int checks;
static void check(struct device *dev, int expected)
{
 struct ssc_sensor before = *dev->iio->priv;
 char buf[32], text[32];
 int n = snprintf(text, sizeof(text), "%d\n", expected);
 memset(buf, 0x5a, sizeof(buf));
 assert(ssc_proximity_input_abi_show(dev, NULL, buf) == n);
 assert(!memcmp(buf, text, (size_t)n + 1));
 assert(!memcmp(&before, dev->iio->priv, sizeof(before)));
 assert((unsigned char)buf[n + 1] == 0x5a);
 checks++;
}
int main(void)
{
 struct ssc_description accel = {SSC_ACCEL}, prox = {SSC_PROXIMITY}, light = {SSC_LIGHT};
 struct ssc_controller c = {};
 struct iio_dev iio = {&c.sensor[0]};
 struct device dev = {&iio};
 check(&dev, 0); /* Undeclared sensors must not dereference NULL descriptions. */
 for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++) {
  iio.priv = &c.sensor[i];
  c.sensor[i] = (struct ssc_sensor){false, &prox}; check(&dev, 0);
  c.sensor[i] = (struct ssc_sensor){true, &accel}; check(&dev, 0);
  c.sensor[i] = (struct ssc_sensor){true, &light}; check(&dev, 0);
  c.sensor[i] = (struct ssc_sensor){true, &prox}; check(&dev, 1);
  c.sensor[i].declared = false; check(&dev, 0);
  c.sensor[i] = (struct ssc_sensor){};
 }
 for (unsigned int i = 0; i < SSC_SENSOR_COUNT; i++) c.sensor[i] = (struct ssc_sensor){true, &prox};
 check(&dev, 1);
 assert(checks == 62);
 puts("Actual proximity ABI:62 declared/absent/type/state-preservation cases; no hardware acceptance.");
 return 0;
}
