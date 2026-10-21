#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Host-only kernel-C/data fixture; no device application or hardware operation.
set -Eeuo pipefail
[[ $# == 2 ]] || exit 2
kernel=$(realpath -- "$1")
oem=$(realpath -- "$2")
oem_header=$(realpath -- "$(dirname -- "$oem")/../../../include/dt-bindings/clock/qcom,camcc-cliffs.h")
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
candidate=$project/src/camera/camcc-sm7675-data.h
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
printf '%s  %s\n' \
  1a76c029c51710af6684a6d4f87e1486c125cd25badfce7b80ba642d820affe6 "$oem" \
  03de8c3ce8774f88c92c65cd09ac9b6c7169a62112596872242f779b7817dad9 "$oem_header" \
  58333db1f02cd0d39d7b96d71ff828d35734eae67165c4b6aa573a1b61d815eb "$kernel/drivers/clk/qcom/vdd-class.c" \
  5d9ac761527a5fa82aa540305690b2b6f4a9a091dcd4a956dae02960b5d95edf "$kernel/drivers/clk/qcom/vdd-level.h" | sha256sum -c -

for role in oem candidate; do
    input=$candidate
    [[ $role != oem ]] || input=$oem
    awk '
      /^static (const )?struct / {
        name=""; if(match($0,/cam_cc_[A-Za-z0-9_]+/))name=substr($0,RSTART,RLENGTH)
      }
      name!="" && /\.(cmd_rcgr|halt_reg|enable_reg|offset) = 0x/ {
        line=$0; gsub(/^[ \t]+|[,;]$/,"",line); print name,line
      }
      /^};/ {name=""}
    ' "$input" | LC_ALL=C sort > "$work/$role.registers"
    awk '
      /^static const struct freq_tbl / {table=$5; sub(/\[\]/,"",table)}
      /^[[:space:]]*F\(/ {line=$0; gsub(/[[:space:]]/,"",line); print table,line}
      /^};/ {table=""}
    ' "$input" > "$work/$role.frequencies"
done
diff -u "$work/oem.registers" "$work/candidate.registers"
diff -u "$work/oem.frequencies" "$work/candidate.frequencies"
[[ $(wc -l < "$work/candidate.registers") -eq 209 ]]
[[ $(wc -l < "$work/candidate.frequencies") -eq 86 ]]
awk '/^#define CAM_CC/ && $2 !~ /_GDSC$/ {print $2,$3}' "$oem_header" | LC_ALL=C sort > "$work/oem.ids"
awk '/^#define CAM_CC/ && $2 !~ /_GDSC$/ {print $2,$3}' "$project/src/camera/include/dt-bindings/clock/qcom,sm7675-camcc.h" | LC_ALL=C sort > "$work/candidate.ids"
diff -u "$work/oem.ids" "$work/candidate.ids"
[[ $(wc -l < "$work/candidate.ids") -eq 147 ]]

for role in oem candidate; do
    input=$candidate
    [[ $role != oem ]] || input=$oem
    {
        cat <<'C'
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define min(a,b) ((a) < (b) ? (a) : (b))
#define DIV_ROUND_CLOSEST(a,b) (((a) + (b)/2) / (b))
#define pr_err(...) fprintf(stderr, __VA_ARGS__)
struct clk_hw { int unused; };
static const char *clk_hw_get_name(struct clk_hw *hw) { (void)hw; return "camcc-model"; }
struct clk_vdd_class { int num_levels; };
struct clk_vdd_class_data {
    struct clk_vdd_class *vdd_class;
    struct clk_vdd_class **vdd_classes;
    unsigned long *rate_max;
    int num_rate_max, num_vdd_classes;
};
struct clk_regmap { struct clk_hw hw; struct clk_vdd_class_data vdd_data; };
struct fixture_clock { struct clk_regmap clkr; };
#define DEFINE_VDD_REGULATORS(name,levels,count,table) struct clk_vdd_class name = { .num_levels = (levels) }
C
        sed -n '/^enum vdd_levels {/,/^};/p' "$kernel/drivers/clk/qcom/vdd-level.h"
        awk '
          /^int clk_find_vdd_level\(/ {inside=1}
          inside {print; if ($0=="}") inside=0}
        ' "$kernel/drivers/clk/qcom/vdd-class.c"
        awk '
          function normalized(line) {
            gsub(/cam_cc_cliffs_regulators_1/, "cam_cc_sm7675_mm_mxc", line)
            gsub(/cam_cc_cliffs_regulators/, "cam_cc_sm7675_regulators", line)
            gsub(/\<vdd_mm\>/, "cam_cc_mm", line)
            gsub(/\<vdd_mx\>/, "cam_cc_mx", line)
            gsub(/\<vdd_mxc\>/, "cam_cc_mxc", line)
            return line
          }
          /static DEFINE_VDD_REGULATORS\(/ {print normalized($0)}
          /^static struct clk_vdd_class \*/ {group=1}
          group {print normalized($0); if($0=="};")group=0}
          /^static struct / {
            name=""; if(match($0,/cam_cc_[A-Za-z0-9_]+/))name=substr($0,RSTART,RLENGTH)
          }
          name!="" && /\.vdd_data = \{/ {inside=1; depth=0; block=""}
          inside {
            line=$0; open=gsub(/\{/,"{",line); close_count=gsub(/\}/,"}",line); depth+=open-close_count
            text=normalized($0); sub(/\.clkr\.vdd_data/,".vdd_data",text); block=block text "\n"
            if(!depth) {
              printf "static struct fixture_clock %s = {.clkr = {\n%s}};\n",name,block
              names[++count]=name; inside=0
            }
          }
          END {
            print "struct record { const char *name; struct clk_regmap *clock; };"
            print "static struct record records[] = {"
            for(i=1;i<=count;i++)printf "{\"%s\", &%s.clkr},\n",names[i],names[i]
            print "};"
          }
        ' "$input"
        sed -n '/^static struct clk_regmap \*cam_cc_voltage_clocks\[\]/,/^};/p' "$candidate"
        awk '/^static int cam_cc_voltage_limit\(/,/^}/' "$candidate"
        awk '/^static int cam_cc_validate_voltage_data\(/,/^}/' "$candidate"
        cat <<'C'
static unsigned int rail_mask(const struct clk_vdd_class *rail)
{
    if (rail == &cam_cc_mm) return 1;
    if (rail == &cam_cc_mx) return 2;
    assert(rail == &cam_cc_mxc);
    return 4;
}
int main(void)
{
    assert(ARRAY_SIZE(records) == 44 && ARRAY_SIZE(cam_cc_voltage_clocks) == 44);
#ifdef CANDIDATE
    assert(cam_cc_validate_voltage_data() == 0);
#else
    /* OEM HIGH_L1 points exceed its separately declared supply-class ceiling. */
    assert(cam_cc_validate_voltage_data() == -ERANGE);
#endif
    for (size_t i=0; i<ARRAY_SIZE(records); ++i) {
        struct clk_regmap *clock=records[i].clock;
        struct clk_vdd_class_data *data=&clock->vdd_data;
        unsigned int mask=0, found=0;
        int limit=cam_cc_voltage_limit(data);
        assert(limit > 0);
        for(size_t j=0; j<ARRAY_SIZE(cam_cc_voltage_clocks); ++j)
            found += cam_cc_voltage_clocks[j] == clock;
        assert(found == 1);
        if(data->vdd_class) mask=rail_mask(data->vdd_class);
        else for(int j=0;j<data->num_vdd_classes;++j)mask|=rail_mask(data->vdd_classes[j]);
        unsigned long last=0;
        for(int level=1;level<limit;++level) {
            unsigned long rate=data->rate_max[level];
            if(!rate)continue;
            assert(clk_find_vdd_level(&clock->hw,data,rate) == level);
            printf("%s\t%u\t%d\t%lu\n",records[i].name,mask,level,rate);
            last=rate;
        }
        assert(last);
        assert(clk_find_vdd_level(&clock->hw,data,0) == -EINVAL);
#ifdef CANDIDATE
        assert(clk_find_vdd_level(&clock->hw,data,last+1000) < 0);
#endif
    }
#ifdef CANDIDATE
    struct clk_vdd_class_data saved=cam_cc_pll0.clkr.vdd_data;
    cam_cc_pll0.clkr.vdd_data.vdd_class=&cam_cc_mx;
    assert(cam_cc_validate_voltage_data() == -ERANGE);
    cam_cc_pll0.clkr.vdd_data=saved;
    cam_cc_pll0.clkr.vdd_data.vdd_class=NULL;
    assert(cam_cc_validate_voltage_data() == -EINVAL);
    cam_cc_pll0.clkr.vdd_data=saved;
    cam_cc_pll0.clkr.vdd_data.num_vdd_classes=1;
    assert(cam_cc_validate_voltage_data() == -EINVAL);
    cam_cc_pll0.clkr.vdd_data=saved;
    unsigned long old=cam_cc_pll0.clkr.vdd_data.rate_max[VDD_NOMINAL];
    cam_cc_pll0.clkr.vdd_data.rate_max[VDD_NOMINAL]=1;
    assert(cam_cc_validate_voltage_data() == -EINVAL);
    cam_cc_pll0.clkr.vdd_data.rate_max[VDD_NOMINAL]=old;
    assert(cam_cc_validate_voltage_data() == 0);
    assert(cam_cc_mclk0_clk_src.clkr.vdd_data.vdd_class == &cam_cc_mx);
    assert(cam_cc_mclk4_clk_src.clkr.vdd_data.vdd_class == &cam_cc_mx);
    assert(clk_find_vdd_level(&cam_cc_pll0.clkr.hw,&saved,2000000000UL) == VDD_NOMINAL);
    assert(clk_find_vdd_level(&cam_cc_pll0.clkr.hw,&saved,2300000000UL) == -EINVAL);
#endif
    return 0;
}
C
    } > "$work/$role.c"
    extra=()
    [[ $role != candidate ]] || extra=(-DCANDIDATE)
    read -r -a flags <<< "${CAMCC_TEST_FLAGS:-}"
    "${CC:-cc}" -std=gnu11 -O1 -g -Wall -Wextra -Werror "${extra[@]}" "${flags[@]}" "$work/$role.c" -o "$work/$role"
    if "$work/$role" > "$work/$role.tsv" 2> "$work/$role.log"; then
        :
    else
        test_rc=$?
        cat "$work/$role.log" >&2
        exit "$test_rc"
    fi
done
diff -u "$work/oem.tsv" "$work/candidate.tsv"
printf '%s\n' 'CAMCC: 209 register fields, 86 frequency rows, 147 clock/reset IDs and all 44 legal OEM voltage policies match; malformed tables refused.'
