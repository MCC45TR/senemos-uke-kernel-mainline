#!/usr/bin/bash
# COPR only: actual upstream initializers, normal park/restore and real provider.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");out=$(realpath "$2")
here=$(cd -- "$(dirname -- "$0")/.." && pwd)
result=$PWD/display-handoff734-result
bash "$here/src/display/handoff734/apply-source.sh" "$kernel" "$result"
extract() {
    awk -v name="$1" '
      $0 ~ "^static (int|void) " name "\\(" {emit=1}
      emit {print}
      emit && /^}/ {exit}
    ' "$kernel/drivers/clk/qcom/clk-rcg2.c"
}
cat > "$result/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
typedef uint32_t u32;
#define CFG_REG 4
#define CFG_SRC_SEL_SHIFT 8
struct regmap { u32 cfg; unsigned reads,writes,force_on,force_off,updates; };
struct clk_hw { unsigned unused; };
struct clk_regmap { struct clk_hw hw; struct regmap *regmap; };
struct clk_rcg2 { struct clk_regmap clkr; u32 cmd_rcgr,parked_cfg,safe_src_index; };
#define to_clk_rcg2(hw) ((struct clk_rcg2 *)(hw))
static int regmap_read(struct regmap *map,u32 offset,u32 *value) {
 assert(offset==0x8080+CFG_REG);map->reads++;*value=map->cfg;return 0;
}
static int regmap_write(struct regmap *map,u32 offset,u32 value) {
 assert(offset==0x8080+CFG_REG);map->writes++;map->cfg=value;return 0;
}
static int clk_rcg2_set_force_enable(struct clk_hw *hw) {to_clk_rcg2(hw)->clkr.regmap->force_on++;return 0;}
static int clk_rcg2_clear_force_enable(struct clk_hw *hw) {to_clk_rcg2(hw)->clkr.regmap->force_off++;return 0;}
static int update_config(struct clk_rcg2 *rcg) {rcg->clkr.regmap->updates++;return 0;}
C
for function in clk_rcg2_shared_disable clk_rcg2_shared_enable clk_rcg2_shared_init clk_rcg2_shared_no_init_park;do
 extract "$function" > "$result/$function.c"
 [[ -s $result/$function.c ]]
 cat "$result/$function.c" >> "$result/check.c"
done
cat >> "$result/check.c" <<'C'
static void verify_init(int (*init)(struct clk_hw *),u32 inherited) {
 struct regmap map={.cfg=inherited};
 struct clk_rcg2 rcg={.clkr.regmap=&map,.cmd_rcgr=0x8080,.parked_cfg=0xdeadbeef,.safe_src_index=0};
 assert(init(&rcg.clkr.hw)==0);
 assert(map.cfg==inherited && rcg.parked_cfg==inherited && map.reads==1);
 assert(!map.writes && !map.force_on && !map.force_off && !map.updates);
 /* The normal consumer lifecycle must still park and restore the inherited config. */
 clk_rcg2_shared_disable(&rcg.clkr.hw);
 assert(!map.cfg && rcg.parked_cfg==inherited && map.writes==1 && map.updates==1);
 assert(clk_rcg2_shared_enable(&rcg.clkr.hw)==0);
 assert(map.cfg==inherited && rcg.parked_cfg==inherited && map.writes==2 && map.updates==2);
 assert(map.force_on==2 && map.force_off==2);
}
static void stale_init(struct clk_hw *hw) {(void)hw;}
static int stale_adapter(struct clk_hw *hw) {stale_init(hw);return 0;}
static void rejected(int (*init)(struct clk_hw *)) {
 pid_t pid=fork();assert(pid>=0);
 if(!pid){freopen("/dev/null","w",stderr);verify_init(init,0x105);_exit(0);}
 int status=0;assert(waitpid(pid,&status,0)==pid);
 assert(WIFSIGNALED(status));
}
int main(void) {
 const u32 configs[]={0x105,0x107,0x209,0x30b};
 for(unsigned i=0;i<sizeof(configs)/sizeof(configs[0]);i++)verify_init(clk_rcg2_shared_no_init_park,configs[i]);
 rejected(clk_rcg2_shared_init);rejected(stale_adapter);
 puts("PASS: display handoff preserves four inherited MDP configurations without writes; normal park/restore retained; parking and missing-cache mutants rejected; synthetic registers only");
}
C
ulimit -c 0
: > "$result/native-results.txt"
for compiler in gcc clang;do
 for mode in plain sanitized;do
  flags=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror)
  [[ $mode != sanitized ]] || flags+=("-fsanitize=address,undefined" -fno-omit-frame-pointer)
  "$compiler" "${flags[@]}" "$result/check.c" -o "$result/check"
  readelf -h "$result/check" | grep -F AArch64
  timeout --kill-after=2s 15s "$result/check" >> "$result/native-results.txt"
 done
done
cat "$result/native-results.txt"
make -s -C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1 KCFLAGS=-Werror -j2 drivers/clk/qcom/dispcc-sm8550.o
llvm-readelf -h "$out/drivers/clk/qcom/dispcc-sm8550.o" | grep -F AArch64
llvm-nm "$out/drivers/clk/qcom/dispcc-sm8550.o" | awk '$NF=="clk_rcg2_shared_no_init_park_ops"&&$(NF-1)=="U"{found=1}END{exit !found}'
(cd "$kernel";sha256sum -c --strict --quiet "$result/source.sha256")
(cd "$out";sha256sum drivers/clk/qcom/dispcc-sm8550.o) > "$result/native-objects.sha256"
[[ $(grep -c '^PASS: display handoff' "$result/native-results.txt") == 4 && ! -e $out/arch/arm64/boot/Image ]]
jq -n '{schema_version:1,compiler_modes:4,actual_arm64_provider_objects:1,firmware_rcg_configuration_preserved:true,normal_park_restore_retained:true,semantic_mutants:2,contains_kernel_image:false,physical_device_accessed:false,physical_acceptance:false}' > "$result/qualification.json"
