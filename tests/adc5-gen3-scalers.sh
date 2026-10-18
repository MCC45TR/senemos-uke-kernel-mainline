#!/usr/bin/env bash
# Host-only tests of the actual PMIC scaler functions; no device access.
set -Eeuo pipefail
kernel=${1:?Pass prepared kernel source}
source=$kernel/drivers/iio/adc/qcom-vadc-common.c
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cat > "$work/test.c" <<'C'
#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
typedef int64_t s64;
typedef int16_t s16;
typedef int32_t s32;
typedef uint16_t u16;
typedef uint32_t u32;
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define RATIO_MAX_ADC7 (1U << 14)
#define R_PU_100K 100000
#define VADC5_MAX_CODE 0x7fff
struct u32_fract {u32 numerator, denominator;};
struct adc5_data {u32 full_scale_code_volt;};
struct vadc_map_pt {int x,y;};
static s64 div64_s64(s64 a,s64 b) {return a/b;}
static s64 div_s64(s64 a,int b) {return a/b;}
static int fixp_linear_interpolate(int x0,int y0,int x1,int y1,int x) {
    if (y0==y1 || x==x0) return y0;
    if (x1==x0 || x==x1) return y1;
    return y0+(y1-y0)*(x-x0)/(x1-x0);
}
C
sed -n '/^static const struct vadc_map_pt adcmap_gen3_batt_therm_100k\[\]/,/^};/p' "$source" >> "$work/test.c"
for fn in qcom_vadc_map_voltage_temp qcom_vadc_scale_code_voltage_factor qcom_vadc_scale_hw_pm7_chg_temp qcom_vadc_scale_hw_calib_current qcom_vadc_scale_hw_calib_current_raw qcom_adc5_gen3_scale_hw_calib_batt_therm_100; do
    awk -v fn="$fn" '
      $0 ~ "^static int "fn"\\(" {capture=1; text=""; body=0}
      capture {text=text $0 "\n"; if($0 ~ /^\{/) body=1;
        if(!body && $0 ~ /;$/) capture=0;
        if(body && $0 ~ /^}/) {printf "%s",text; exit}}
    ' "$source" >> "$work/test.c"
done
cat >> "$work/test.c" <<'C'
int main(void) {
    struct adc5_data data={.full_scale_code_volt=0x70e4};
    struct u32_fract one={1,1}, input={32,100}, charge={1000,366220}, invalid={0,1};
    int value;
    assert(qcom_vadc_scale_hw_calib_current(&invalid,&data,1,&value)==-EINVAL);
    assert(qcom_vadc_scale_hw_calib_current_raw(&invalid,&data,1,&value)==-EINVAL);
    for(unsigned raw=0;raw<=UINT16_MAX;raw++) {
        s64 signed_code=(s16)raw;
        assert(!qcom_vadc_scale_hw_calib_current(&input,&data,raw,&value));
        assert(value==((signed_code*1875000/0x70e4)*100)/32);
        assert(!qcom_vadc_scale_hw_calib_current_raw(&charge,&data,raw,&value));
        assert(value==signed_code*366220/1000);
        assert(!qcom_vadc_scale_hw_pm7_chg_temp(&one,&data,raw,&value));
        s64 uv=raw>0x7fff ? 0 : (s64)raw*1875000/0x70e4;
        s64 expected=(30303*uv-27712000000LL)/100000;
        assert(value==(expected>0 ? expected : 0));
    }
    int previous=100000;
    for(unsigned raw=0;raw<RATIO_MAX_ADC7;raw++) {
        assert(!qcom_adc5_gen3_scale_hw_calib_batt_therm_100(&one,&data,raw,&value));
        assert(value>=-40000 && value<=98000 && value<=previous && value%100==0);
        previous=value;
    }
    assert(qcom_adc5_gen3_scale_hw_calib_batt_therm_100(&one,&data,RATIO_MAX_ADC7,&value)==-EINVAL);
    assert(qcom_adc5_gen3_scale_hw_calib_batt_therm_100(&one,&data,UINT16_MAX,&value)==-EINVAL);
    assert(!qcom_adc5_gen3_scale_hw_calib_batt_therm_100(&one,&data,8192,&value));
    assert(value>=24000 && value<=26000);
    assert(!qcom_vadc_scale_hw_calib_current_raw(&charge,&data,0xffff,&value) && value==-366);
    puts("PMIC Gen3: signed full-code current/charger sweeps, battery units, monotonicity and invalid-input refusals passed");
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/test.c" -o "$work/test"
"$work/test"
