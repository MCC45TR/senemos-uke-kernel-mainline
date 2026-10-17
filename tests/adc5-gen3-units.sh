#!/usr/bin/env bash
set -Eeuo pipefail
source=${1:?Pass prepared kernel source}/drivers/iio/adc/qcom-spmi-adc5-gen3.c
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cat > "$work/test.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
typedef uint16_t u16;
enum { IIO_VOLTAGE, IIO_TEMP, IIO_CURRENT, IIO_CHAN_INFO_PROCESSED=10, IIO_VAL_INT=20, IIO_VAL_FRACTIONAL };
struct adc5_channel_common_prop { int scale_fn_type, prescale; };
struct adc5_channel_prop { struct adc5_channel_common_prop common_props; };
struct adc5_chip { struct adc5_channel_prop chan_props[1]; int data; };
struct iio_dev { struct adc5_chip chip; };
struct iio_chan_spec { int address, type; };
static int conversion_error, scale_error, reading;
static bool scaled;
static struct adc5_chip *iio_priv(struct iio_dev *dev) { return &dev->chip; }
static int adc5_gen3_do_conversion(struct adc5_chip *adc, struct adc5_channel_common_prop *prop, u16 *raw)
{ (void)adc; (void)prop; *raw=100; return conversion_error; }
static int qcom_adc5_hw_scale(int type, int pre, int data, u16 raw, int *val)
{ (void)type; (void)pre; (void)data; assert(raw==100); scaled=true; *val=reading; return scale_error; }
C
awk '/^static int adc5_gen3_read_raw\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$source" >> "$work/test.c"
cat >> "$work/test.c" <<'C'
int main(void) {
    struct iio_dev dev={0}; struct iio_chan_spec chan={.type=IIO_VOLTAGE}; int val, div;
    reading=4999123; div=0;
    assert(adc5_gen3_read_raw(&dev,&chan,&val,&div,IIO_CHAN_INFO_PROCESSED)==IIO_VAL_FRACTIONAL);
    assert(val==4999123 && div==1000 && scaled);
    chan.type=IIO_CURRENT; reading=-366; div=0;
    assert(adc5_gen3_read_raw(&dev,&chan,&val,&div,IIO_CHAN_INFO_PROCESSED)==IIO_VAL_FRACTIONAL);
    assert(val==-366 && div==1000);
    chan.type=IIO_TEMP; reading=32123; div=-1;
    assert(adc5_gen3_read_raw(&dev,&chan,&val,&div,IIO_CHAN_INFO_PROCESSED)==IIO_VAL_INT);
    assert(val==32123 && div==-1);
    conversion_error=-EIO; scaled=false;
    assert(adc5_gen3_read_raw(&dev,&chan,&val,&div,IIO_CHAN_INFO_PROCESSED)==-EIO && !scaled);
    conversion_error=0; scale_error=-ERANGE;
    assert(adc5_gen3_read_raw(&dev,&chan,&val,&div,IIO_CHAN_INFO_PROCESSED)==-ERANGE);
    assert(adc5_gen3_read_raw(&dev,&chan,&val,&div,-1)==-EINVAL);
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/test.c" -o "$work/test"
"$work/test"
for channel in USB_SNS_V_16 VIN_DIV16_MUX; do
    grep -Eq "\[ADC5_GEN3_${channel}\].*= ADC5_CHAN_VOLT\(" "$source"
done
printf '%s\n' 'ADC5 Gen3 voltage units, temperature preservation and failure propagation passed'
