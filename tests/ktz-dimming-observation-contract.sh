#!/usr/bin/env bash
# Host-only fault fixture of the actual bound-driver observer and visibility.
set -Eeuo pipefail
source_file=${1:?Pass prepared drivers/video/backlight/ktz8866.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include <sys/types.h>
using umode_t = unsigned short;
#define BIT(n) (1U << (n))
struct device;
struct kobject { device *dev; };
struct device { void *data; kobject kobj; };
struct attribute { const char *name; umode_t mode; };
struct device_attribute {
    attribute attr;
    ssize_t (*show)(device *, device_attribute *, char *);
};
struct attribute_group {
    attribute **attrs;
    umode_t (*is_visible)(kobject *, attribute *, int);
};
#define DEVICE_ATTR_RO(name) device_attribute dev_attr_##name{{#name,0444},name##_show}
#define __ATTRIBUTE_GROUPS(name) static const attribute_group *name##_groups[] = {&name##_group,nullptr}
struct mutex { bool locked=false; };
struct regmap { unsigned int regs[22]; int error=0; };
struct ktz8866 {
    struct regmap *regmap;
    ktz8866 *peer;
    mutex lock;
    bool uke=true, secondary=false;
    void *backlight;
};
mutex *expected_lock;
regmap *expected_maps[2];
int reads, locks, unlocks;
void *dev_get_drvdata(device *dev) { return dev->data; }
device *kobj_to_dev(kobject *kobj) { return kobj->dev; }
void mutex_lock(mutex *lock) {
    assert(lock==expected_lock && !lock->locked); lock->locked=true; locks++;
}
void mutex_unlock(mutex *lock) {
    assert(lock==expected_lock && lock->locked); lock->locked=false; unlocks++;
}
int regmap_read(regmap *map, unsigned int reg, unsigned int *value) {
    assert(expected_lock->locked && reads<2 && map==expected_maps[reads]);
    assert(reg==2); reads++;
    if(map->error) return map->error; // Leave the output uninitialized on error.
    *value=map->regs[reg]; return 0;
}
int sysfs_emit(char *buf, const char *format, ...) {
    assert(!expected_lock->locked);
    va_list args; va_start(args,format);
    int count=vsnprintf(buf,4096,format,args); va_end(args);
    assert(count>=0 && count<4096); return count;
}
// No write, GPIO, direct-I2C or brightness API is supplied to the extracted code.
CPP
    awk '/^#define BL_CFG1 / || /^#define BL_CFG1_(PWM_ENABLE|PWM_CONFIG|BLED_MAP|MODE_MASK) / {print}' "$source_file"
    awk '/^static ssize_t uke_dimming_state_show/ {emit=1} /^struct ktz8866_state/ {emit=0} emit {print}' "$source_file"
    cat <<'CPP'
int main() {
    regmap maps[2]{};
    ktz8866 secondary{&maps[1],nullptr,{},true,true,&maps[1]};
    ktz8866 primary{&maps[0],&secondary,{},true,false,&maps[0]};
    device dev{&primary,{nullptr}}; dev.kobj.dev=&dev;
    expected_lock=&primary.lock; expected_maps[0]=&maps[0]; expected_maps[1]=&maps[1];
    auto *attr=&dev_attr_uke_dimming_state;
    assert(!std::strcmp(attr->attr.name,"uke_dimming_state") && attr->attr.mode==0444);
    assert(ktz8866_uke_groups[0]==&ktz8866_uke_group && !ktz8866_uke_groups[1]);
    assert(ktz8866_uke_group.attrs[0]==&attr->attr && !ktz8866_uke_group.attrs[1]);
    assert(ktz8866_uke_group.is_visible==ktz8866_uke_attr_is_visible);
    assert(ktz8866_uke_group.is_visible(&dev.kobj,&attr->attr,0)==0444);
    auto read=[&](char *buf) {
        reads=locks=unlocks=0;
        unsigned int before[2][22];
        for(int i=0;i<2;i++) std::memcpy(before[i],maps[i].regs,sizeof(before[i]));
        auto ret=attr->show(&dev,attr,buf);
        assert(!primary.lock.locked);
        for(int i=0;i<2;i++) assert(!std::memcmp(before[i],maps[i].regs,sizeof(before[i])));
        return ret;
    };
    char buf[4096], expected[4096];
    // All field combinations and differences in unrelated BL_CFG1 bits.
    for(unsigned int p=0;p<256;p++) for(unsigned int s=0;s<256;s++) {
        for(int i=0;i<22;i++) { maps[0].regs[i]=0xa0+i; maps[1].regs[i]=0xb0+i; }
        maps[0].regs[2]=p; maps[1].regs[2]=s;
        auto ret=read(buf);
        assert(ret==static_cast<ssize_t>(std::strlen(buf)) && reads==2 && locks==1 && unlocks==1);
        const auto difference=(p^s)&0x0d;
        if(difference) {
            std::snprintf(expected,sizeof(expected),
                "status=mismatch primary_cfg1=0x%02x secondary_cfg1=0x%02x mismatch_mask=0x%02x\n",p,s,difference);
            assert(!std::strstr(buf,"mode=") && !std::strstr(buf,"mapping=") && !std::strstr(buf,"pwm_polarity="));
        } else {
            std::snprintf(expected,sizeof(expected),
                "status=ok primary_cfg1=0x%02x secondary_cfg1=0x%02x mode=%s mapping=%s pwm_polarity=%s\n",
                p,s,(p&1)?"i2c-times-pwm":"i2c",(p&8)?"linear":"exponential",(p&4)?"active-low":"active-high");
        }
        assert(!std::strcmp(buf,expected));
    }
    // Errors on either or both adapters: no stale raw value or decoded mode.
    for(int p : {0,-EIO,-EREMOTEIO,-ENXIO}) for(int s : {0,-EIO,-EREMOTEIO,-ENXIO}) {
        if(!p && !s) continue;
        maps[0].error=p; maps[1].error=s;
        std::memset(buf,'?',sizeof(buf));
        assert(read(buf)>0 && reads==2 && locks==1 && unlocks==1);
        std::snprintf(expected,sizeof(expected),"status=read-error primary_errno=%d secondary_errno=%d\n",p,s);
        assert(!std::strcmp(buf,expected));
    }
    maps[0].error=maps[1].error=0;
    // Unready, non-Uke and secondary devices expose no attribute or bus read.
    for(int invalid=0;invalid<5;invalid++) {
        dev.data=&primary; primary.uke=true; primary.secondary=false;
        primary.peer=&secondary; primary.backlight=&maps[0];
        switch(invalid) {
        case 0: dev.data=nullptr; break;
        case 1: primary.uke=false; break;
        case 2: primary.secondary=true; break;
        case 3: primary.peer=nullptr; break;
        case 4: primary.backlight=nullptr; break;
        }
        assert(!ktz8866_uke_group.is_visible(&dev.kobj,&attr->attr,0));
        std::strcpy(buf,"unchanged");
        assert(read(buf)==-ENODEV && !reads && !locks && !unlocks && !std::strcmp(buf,"unchanged"));
    }
}
CPP
} > "$work/check.cpp"
"${CXX:-clang++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/check.cpp" -o "$work/check"
"$work/check"
grep -F '.dev_groups = ktz8866_uke_groups,' "$source_file" >/dev/null
printf 'Actual KTZ8866 paired read-only mode observer, field mismatch, bus faults and visibility: passed\n'
