/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual driver callbacks with synthetic firmware and IIO providers. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define GFP_KERNEL 0
#define BIT(n) (1U << (n))
#define IIO_CHAN_INFO_RAW 0
#define IIO_CHAN_INFO_SCALE 1
#define IIO_CPU 0
#define INDIO_DIRECT_MODE 1
#define IIO_SHARED_BY_TYPE 2
enum iio_modifier { IIO_MOD_X, IIO_MOD_Y, IIO_MOD_Z };
enum ssc_kind { SSC_ACCEL, SSC_GYRO, SSC_LIGHT };
struct device { int unused; };
struct device_node { bool present; int count, read_result; const char *values[10]; };
struct iio_mount_matrix { const char *rotation[9]; };
struct iio_dev;
struct iio_chan_spec;
struct iio_chan_spec_ext_info {
    const char *name;
    int shared;
    const struct iio_mount_matrix *(*get)(const struct iio_dev *, const struct iio_chan_spec *);
};
#define IIO_MOUNT_MATRIX(sh, cb) { .name="mount_matrix", .shared=(sh), .get=(cb) }
struct iio_chan_spec {
    int type, address, scan_index;
    unsigned int info_mask_separate, info_mask_shared_by_type;
    struct { char sign; int realbits, storagebits, endianness; } scan_type;
    int modified, channel2;
    const struct iio_chan_spec_ext_info *ext_info;
};
#define IIO_CHAN_SOFT_TIMESTAMP(n) ((struct iio_chan_spec){ .scan_index=(n) })
struct iio_dev {
    void *priv;
    const char *name;
    const void *info;
    int modes;
    struct iio_chan_spec *channels;
    unsigned int num_channels;
    const unsigned long *available_scan_masks;
};
struct ssc_description { enum ssc_kind kind; unsigned int dimensions, multiplier; int channel; const char *name; };
struct ssc_sensor {
    const struct ssc_description *description;
    struct iio_mount_matrix mount_matrix;
    bool has_mount_matrix;
    struct iio_dev *iio;
    struct iio_chan_spec channel[4];
    int64_t sample[3];
};
struct ssc_controller { struct device *dev; };
static const int ssc_iio_info, ssc_buffer_ops;
static const unsigned long ssc_xyz_masks[]={7,0}, ssc_scalar_masks[]={1,0};
static struct iio_dev allocated_iio;
static struct ssc_sensor *private_sensor;
static char owned[9][8];
static int allocations, fail_allocation, buffer_error;
static bool fail_iio;
static void *iio_priv(const struct iio_dev *iio) { return iio->priv; }
static const void *of_find_property(struct device_node *n, const char *name, void *length)
{
    assert(!strcmp(name,"mount-matrix") && !length);
    return n->present ? n : NULL;
}
static int of_property_count_strings(struct device_node *n, const char *name)
{
    assert(!strcmp(name,"mount-matrix")); return n->count;
}
static int of_property_read_string_array(struct device_node *n, const char *name, const char **out, int count)
{
    assert(!strcmp(name,"mount-matrix") && count==9);
    if(n->read_result==9)memcpy(out,n->values,9*sizeof(*out));
    return n->read_result;
}
static char *devm_kstrdup(struct device *dev, const char *s, int flags)
{
    assert(dev && !flags && allocations<9);
    if(allocations==fail_allocation)return NULL;
    assert(strlen(s)<sizeof owned[0]);
    return strcpy(owned[allocations++],s);
}
static struct iio_dev *devm_iio_device_alloc(struct device *dev, size_t size)
{
    assert(dev && size==sizeof(private_sensor));
    if(fail_iio)return NULL;
    allocated_iio=(struct iio_dev){.priv=&private_sensor};return &allocated_iio;
}
static int devm_iio_kfifo_buffer_setup(struct device *dev, struct iio_dev *iio, const void *ops)
{
    assert(dev && iio==&allocated_iio && ops==&ssc_buffer_ops);return buffer_error;
}
#include "ssc-mount-actual.h"
int main(void)
{
    struct device dev={0};
    struct ssc_controller c={.dev=&dev};
    const struct ssc_description accel={SSC_ACCEL,3,1000000,1,"synthetic-accel"};
    const struct ssc_description gyro={SSC_GYRO,3,1000000,2,"synthetic-gyro"};
    const struct ssc_description light={SSC_LIGHT,2,1000000,3,"synthetic-light"};
    struct ssc_sensor s={.description=&accel,.sample={3,-7,11}};
    struct device_node node={.present=false,.count=9,.read_result=9,
        .values={"0","1","0","-1","0","0","0","0","1"}};
    fail_allocation=-1;
    assert(!ssc_read_mount_matrix(&c,&s,&node) && !s.has_mount_matrix && !allocations);
    assert(!ssc_allocate_iio(&c,&s));
    for(unsigned int i=0;i<4;i++)assert(!s.channel[i].ext_info);
    node.present=true;
    for(int n=-EILSEQ;n<=10;n++) {
        if(n<0 && n!=-EILSEQ)continue;
        if(n==9)continue;
        node.count=n;
        assert(ssc_read_mount_matrix(&c,&s,&node)==(n<0?n:-EINVAL));
        assert(!s.has_mount_matrix && !allocations);
    }
    node.count=9;
    for(int n=-EILSEQ;n<9;n++) {
        if(n<0 && n!=-EILSEQ)continue;
        node.read_result=n;
        assert(ssc_read_mount_matrix(&c,&s,&node)==(n<0?n:-EINVAL));
        assert(!s.has_mount_matrix && !allocations);
    }
    node.read_result=9;
    for(fail_allocation=0;fail_allocation<9;fail_allocation++) {
        allocations=0;
        assert(ssc_read_mount_matrix(&c,&s,&node)==-ENOMEM && !s.has_mount_matrix);
    }
    allocations=0;fail_allocation=-1;
    assert(!ssc_read_mount_matrix(&c,&s,&node) && s.has_mount_matrix && allocations==9);
    for(unsigned int i=0;i<9;i++) {
        assert(s.mount_matrix.rotation[i]!=node.values[i]);
        assert(!strcmp(s.mount_matrix.rotation[i],node.values[i]));
    }
    assert(!ssc_allocate_iio(&c,&s));
    for(unsigned int i=0;i<3;i++) {
        const struct iio_chan_spec_ext_info *ext=s.channel[i].ext_info;
        assert(ext && !strcmp(ext->name,"mount_matrix") && ext->shared==IIO_SHARED_BY_TYPE);
        assert(ext->get(s.iio,&s.channel[i])==&s.mount_matrix && !ext[1].name);
    }
    assert(!s.channel[3].ext_info && s.iio->num_channels==4);
    assert(s.sample[0]==3 && s.sample[1]==-7 && s.sample[2]==11);
    for(unsigned int n=0;n<2;n++) {
        s=(struct ssc_sensor){.description=n?&light:&gyro};
        assert(ssc_read_mount_matrix(&c,&s,&node)==-EINVAL && !s.has_mount_matrix);
        node.present=false;
        assert(!ssc_read_mount_matrix(&c,&s,&node));
        assert(!ssc_allocate_iio(&c,&s));
        for(unsigned int i=0;i<4;i++)assert(!s.channel[i].ext_info);
        node.present=true;
    }
    s=(struct ssc_sensor){.description=&accel};fail_iio=true;
    assert(ssc_allocate_iio(&c,&s)==-ENOMEM);
    fail_iio=false;buffer_error=-EIO;
    assert(ssc_allocate_iio(&c,&s)==-EIO);
    puts("Actual SSC mount callbacks: unknown/malformed/refusal/allocation paths, owned strings, per-type IIO metadata and unchanged sample axes pass; synthetic providers only");
}
