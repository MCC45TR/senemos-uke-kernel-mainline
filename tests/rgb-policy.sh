#!/usr/bin/env bash
# Exercise the actual kernel policy without hardware or a kernel build.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
cat > "$stage/test.c" <<'C'
#include <assert.h>
#include <limits.h>
#include "uke-rgb-policy.h"
int main(void) {
    assert(uke_rgb_battery_mode(16,UKE_RGB_LOW_BATTERY)==UKE_RGB_OFF);
    assert(uke_rgb_battery_mode(15,UKE_RGB_OFF)==UKE_RGB_LOW_BATTERY);
    assert(uke_rgb_battery_mode(14,UKE_RGB_OFF)==UKE_RGB_LOW_BATTERY);
    assert(uke_rgb_battery_mode(6,UKE_RGB_OFF)==UKE_RGB_LOW_BATTERY);
    assert(uke_rgb_battery_mode(5,UKE_RGB_OFF)==UKE_RGB_CRITICAL_BATTERY);
    assert(uke_rgb_battery_mode(4,UKE_RGB_OFF)==UKE_RGB_CRITICAL_BATTERY);
    assert(uke_rgb_battery_mode(0,UKE_RGB_OFF)==UKE_RGB_CRITICAL_BATTERY);
    assert(uke_rgb_battery_mode(-1,UKE_RGB_CRITICAL_BATTERY)==UKE_RGB_CRITICAL_BATTERY);
    assert(uke_rgb_battery_mode(101,UKE_RGB_LOW_BATTERY)==UKE_RGB_LOW_BATTERY);
    assert(uke_rgb_select(1,1,UKE_RGB_CRITICAL_BATTERY,1)==UKE_RGB_FRONT_CAMERA);
    assert(uke_rgb_select(0,1,UKE_RGB_CRITICAL_BATTERY,1)==UKE_RGB_TEST);
    assert(uke_rgb_select(0,0,UKE_RGB_LOW_BATTERY,1)==UKE_RGB_LOW_BATTERY);
    assert(uke_rgb_select(0,0,UKE_RGB_OFF,1)==UKE_RGB_MANUAL);
    for(unsigned t=0;t<20000;++t) {
        struct uke_rgb_frame f=uke_rgb_frame(UKE_RGB_LOW_BATTERY,t,0,0);
        assert(f.rgb==0xff0000 && f.brightness<=8 && f.delay_ms>0);
        if(t%13000>=3000)assert(f.brightness==0);
        if(t%13000>=1000 && t%13000<2000)assert(f.brightness==8);
        struct uke_rgb_frame same=uke_rgb_frame(UKE_RGB_LOW_BATTERY,t+13000,0,0);
        assert(same.brightness==f.brightness && same.delay_ms==f.delay_ms);
        f=uke_rgb_frame(UKE_RGB_CRITICAL_BATTERY,t,0,0);
        assert(f.rgb==0xff0000 && f.brightness<=8 && f.delay_ms>0);
        if(t%5500>=2500)assert(f.brightness==0);
        if(t%5500>=1000 && t%5500<1500)assert(f.brightness==8);
        same=uke_rgb_frame(UKE_RGB_CRITICAL_BATTERY,t+5500,0,0);
        assert(same.brightness==f.brightness && same.delay_ms==f.delay_ms);
        f=uke_rgb_frame(UKE_RGB_FRONT_CAMERA,t,0,0);
        assert(f.rgb==0x00ff00 && f.brightness<=8 && f.delay_ms>0);
        same=uke_rgb_frame(UKE_RGB_FRONT_CAMERA,t+2000,0,0);
        assert(same.brightness==f.brightness && same.delay_ms==f.delay_ms);
        f=uke_rgb_frame(UKE_RGB_TEST,t,0,0);
        assert(f.rgb<=0xffffff && f.brightness<=8);
        if(t<10000)assert(f.delay_ms>0);
        else assert(f.brightness==0 && f.delay_ms==0);
    }
    for(unsigned mode=UKE_RGB_LOW_BATTERY;mode<=UKE_RGB_CRITICAL_BATTERY;++mode) {
        unsigned hold=mode==UKE_RGB_LOW_BATTERY?1000:500;
        assert(uke_rgb_frame(mode,0,0,0).brightness==0);
        assert(uke_rgb_frame(mode,1000,0,0).brightness==8);
        assert(uke_rgb_frame(mode,1000+hold,0,0).brightness==8);
        assert(uke_rgb_frame(mode,2000+hold,0,0).brightness==0);
        for(unsigned t=0;t<1000;++t) {
            assert(uke_rgb_frame(mode,t+1,0,0).brightness>=uke_rgb_frame(mode,t,0,0).brightness);
            assert(uke_rgb_frame(mode,1000+hold+t+1,0,0).brightness<=uke_rgb_frame(mode,1000+hold+t,0,0).brightness);
        }
    }
    unsigned pulses=0,previous=0;
    for(unsigned t=0;t<=6000;++t) {
        struct uke_rgb_frame f=uke_rgb_frame(UKE_RGB_CHARGE_COMPLETE,t,0,0);
        if(f.brightness && !previous)++pulses;
        previous=f.brightness;
        if(t<4500)assert(f.rgb==0x0000ff && f.brightness==(t%1500<1000?0:8) && f.delay_ms>0);
        else assert(!f.brightness && !f.delay_ms);
    }
    assert(pulses==3);
    struct uke_rgb_charge charge={0};
    for(unsigned i=0;i<1000;++i)assert(!uke_rgb_charge_event(&charge,80,80,1,1));
    assert(!uke_rgb_charge_event(&charge,80,79,0,0));
    assert(!uke_rgb_charge_event(&charge,80,80,1,1));
    assert(!uke_rgb_charge_event(&charge,80,78,0,0) && charge.armed);
    assert(!uke_rgb_charge_event(&charge,80,80,0,1));
    assert(!uke_rgb_charge_event(&charge,80,80,1,0));
    assert(uke_rgb_charge_event(&charge,80,80,1,1) && !charge.armed);
    for(unsigned i=0;i<1000;++i)assert(!uke_rgb_charge_event(&charge,80,80,1,1));
    assert(!uke_rgb_charge_event(&charge,75,80,1,1));
    assert(!uke_rgb_charge_event(&charge,75,73,0,0) && charge.armed);
    assert(!uke_rgb_charge_event(&charge,0,73,1,1) && charge.armed);
    assert(!uke_rgb_charge_event(&charge,75,-1,1,1) && charge.armed);
    assert(uke_rgb_charge_event(&charge,75,75,1,1));
    assert(!uke_rgb_frame(UKE_RGB_OFF,0,0,0).delay_ms);
    const unsigned colors[]={0xff0000,0xffff00,0x00ff00,0x00ffff,0x0000ff,0xff00ff};
    for(unsigned i=0;i<6;++i)assert(uke_rgb_frame(UKE_RGB_TEST,(i*10000+5)/6,0,0).rgb==colors[i]);
    assert(uke_rgb_frame(UKE_RGB_MANUAL,0,0xffff00,UINT_MAX).brightness==8);
    assert(sizeof(struct uke_rgb_color)==16 && sizeof(struct uke_rgb_status)==56);
}
C
${CC:-cc} -std=c11 -Wall -Wextra -Werror -I "$root/src/leds" "$stage/test.c" -o "$stage/test"
"$stage/test"
printf '%s\n' 'Actual kernel RGB policy: inclusive thresholds, exact red fades/holds/off, finite three blue pulses, two-point charge hysteresis, stale telemetry and unchanged camera/PWM/ABI limits passed; no hardware operation.'
