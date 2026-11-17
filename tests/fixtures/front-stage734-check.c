/* SPDX-License-Identifier: GPL-2.0-only */
/* Actual entry, front helper and tag converter; synthetic graph, no device I/O. */
#include <stdbool.h>
#include <stdlib.h>
#include <setjmp.h>
#define main front_contract_main
#include "front-eeprom-fdt-check.c"
#undef main
#include "bwmon-tags.h"
#define __init
typedef uintptr_t phys_addr_t;
#define __pa_symbol(v) ((phys_addr_t)(uintptr_t)(v))
static jmp_buf refusal;
static unsigned int critical, gate_calls, native_calls;
#define pr_crit(...) do { critical++; } while (0)
#define pr_warn(...) do { } while (0)
#define pr_info(...) do { } while (0)
#define cpu_relax() longjmp(refusal, 1)
static _Alignas(8) unsigned char uke_fdt[131072], saved_input[65536];
static unsigned char uke_ufs_overlay[8], uke_usb_overlay[8], uke_lights_overlay[8];
struct uke_native_panel { unsigned int unused; };
static const struct uke_native_panel uke_native_panels[] = {{0}};
static int base_result, native_error;
static bool omit_mc, omit_gem;
static int tracked_front_gate(void *dt) __attribute__((unused));
static int tracked_front_gate(void *dt)
{
 gate_calls++;
 return uke_front_eeprom_graph(dt);
}
static int uke_abl_transform(void *out, size_t capacity, const void *in, size_t bytes,
                             void *ufs, size_t ufs_bytes, void *usb, size_t usb_bytes)
{
 (void)bytes; (void)ufs; (void)ufs_bytes; (void)usb; (void)usb_bytes;
 if (base_result != 1) return base_result;
 int ret = fdt_open_into(in, out, capacity);
#if EARLY_FRONT_GATE && defined(CONFIG_SM_CAMCC_7675)
 if (!ret) ret = tracked_front_gate(out);
#endif
 if (!ret) ret = fdt_pack(out);
 return ret ? ret : 1;
}
static int uke_abl_native_select(void *dt, const struct uke_native_panel *panels,
                                unsigned int count)
{
 assert(panels == uke_native_panels && count == 1);
 native_calls++;
 if (native_error) return native_error;
 /* The real native selection runs these two converters before packing. */
 int ret = omit_mc ? 0 : uke_bwmon_mc_tags(dt, 24);
 if (!ret && !omit_gem) ret = uke_bwmon_mc_tags(dt, 21);
 return ret ? ret : fdt_pack(dt);
}
static int uke_audio_config_graph(void *dt)
{
 /* Preserve the following consumer's place in the production entry. */
 assert(native_calls == 1);
#ifdef CONFIG_SM_CAMCC_7675
 assert(gate_calls == 1);
 assert(fdt_path_offset(dt, UKE_FRONT_NEW) >= 0);
#else
 assert(gate_calls == 0);
 assert(fdt_path_offset(dt, UKE_FRONT_OLD) >= 0);
#endif
 return 0;
}
static bool uke_lights_admitted(const void *dt) { (void)dt; return false; }
#define uke_front_eeprom_graph tracked_front_gate
#include "entry.h"
#undef uke_front_eeprom_graph
static void stage_reset(void)
{
 reset();
 /* Exact stage distinction: original provider tuples have one argument. */
 u("/soc/interconnect@24100000", "#interconnect-cells", 1);
 u("/soc/interconnect@1", "#interconnect-cells", 1);
 A(UKE_FRONT_BUS, "interconnects", 20, 37, 20, 573, 21, 2, 22, 541, 23, 7, 24, 512);
 assert(!fdt_pack(tree));
 memset(uke_fdt, 0, sizeof(uke_fdt));
 base_result = 1; native_error = 0; omit_mc = omit_gem = false;
 critical = gate_calls = native_calls = 0;
}
static void entry_rejected(void)
{
 phys_addr_t physical = 0xfeed;
 memcpy(saved_input, tree, sizeof(tree));
 if (!setjmp(refusal)) {
  (void)uke_abl_prepare_fdt(tree, fdt_totalsize(tree), &physical);
  assert(!"Invalid entry accepted");
 }
 assert(critical == 1 && physical == 0xfeed);
 assert(!memcmp(saved_input, tree, sizeof(tree)));
}
int main(void)
{
 assert(front_contract_main() == 0);
 stage_reset();
 /* Reproduce the missing pre-native dependency without publishing any tree. */
 memcpy(saved_input, tree, sizeof(tree));
 assert(uke_front_eeprom_graph(tree) == -FDT_ERR_BADNCELLS);
 assert(!memcmp(saved_input, tree, sizeof(tree)));
 phys_addr_t physical = 0xfeed;
 assert(!setjmp(refusal));
 assert(uke_abl_prepare_fdt(tree, fdt_totalsize(tree), &physical) == uke_fdt);
 assert(physical == (uintptr_t)uke_fdt && native_calls == 1 && !critical);
 assert(!memcmp(saved_input, tree, sizeof(tree)));
 assert(!fdt_check_full(uke_fdt, fdt_totalsize(uke_fdt)));
#ifdef CONFIG_SM_CAMCC_7675
 assert(gate_calls == 1);
 assert(!fdt_node_check_compatible(uke_fdt, fdt_path_offset(uke_fdt, UKE_FRONT_NEW), "atmel,24c64"));
 assert(uke_front_disabled(uke_fdt, fdt_path_offset(uke_fdt, UKE_FRONT_BUS "/qcom,cam-sensor1")));
 for (unsigned int fault = 0; fault < 6; fault++) {
  stage_reset();
  assert(!fdt_open_into(tree, tree, sizeof(tree)));
  if (fault == 0) omit_mc = true;
  if (fault == 1) omit_gem = true;
  if (fault == 2) u(UKE_FRONT_OLD, "reg", 0x50);
  if (fault == 3) s(UKE_FRONT_BUS "/qcom,cam-sensor1", "status", "okay");
  if (fault == 4) b(UKE_FRONT_OLD, "wp-gpios");
  if (fault == 5) u(UKE_FRONT_BUS, "qcom,clk-freq-out", 100000);
  assert(!fdt_pack(tree));
  entry_rejected();
 }
#else
 assert(gate_calls == 0);
 assert(fdt_path_offset(uke_fdt, UKE_FRONT_NEW) == -FDT_ERR_NOTFOUND);
#endif
 stage_reset(); native_error = -FDT_ERR_BADSTRUCTURE; entry_rejected();
 stage_reset(); base_result = -FDT_ERR_BADVALUE; entry_rejected();
 stage_reset(); base_result = 0; physical = 0xfeed;
 assert(uke_abl_prepare_fdt(tree, fdt_totalsize(tree), &physical) == tree);
 assert(physical == 0xfeed && native_calls == 0 && gate_calls == 0);
 puts("Front stage: actual entry, immutable pre-native refusal, real MC/GEM tag conversion, restored packed-tree capacity, read-only gate, sensor quarantine and fail-closed publication pass; synthetic graph only");
 return 0;
}
