#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
struct socinfo { uint32_t hw_plat, hw_plat_subtype, plat_ver; };
struct qcom_socinfo { const struct socinfo *sensor_info; };
struct device { struct qcom_socinfo *info; };
struct device_attribute { int unused; };
#define le32_to_cpu(v) (v)
#define dev_get_drvdata(d) ((d)->info)
#define DEVICE_ATTR_RO(n) int unused_##n __attribute__((unused))
static int sysfs_emit(char *buf, const char *fmt, ...) {
    va_list args; va_start(args,fmt); int n=vsnprintf(buf,4096,fmt,args); va_end(args); return n;
}
#include "profile-functions.h"
int main(void) {
    struct socinfo raw={8,0,65536}; struct qcom_socinfo qs={&raw}; struct device d={&qs}; char buf[4096];
    assert(hw_platform_show(&d,0,buf)==4 && !strcmp(buf,"MTP\n"));
    assert(platform_subtype_show(&d,0,buf)==8 && !strcmp(buf,"Unknown\n"));
    assert(platform_subtype_id_show(&d,0,buf)==2 && !strcmp(buf,"0\n"));
    assert(platform_version_show(&d,0,buf)==6 && !strcmp(buf,"65536\n"));
    raw.hw_plat=7; assert(hw_platform_show(&d,0,buf)==-ENODATA);
    raw.hw_plat_subtype=1; assert(platform_subtype_show(&d,0,buf)==-ENODATA);
    assert(platform_subtype_id_show(&d,0,buf)==2 && !strcmp(buf,"1\n"));
    raw.plat_ver=0; assert(platform_version_show(&d,0,buf)==2 && !strcmp(buf,"0\n"));
}
