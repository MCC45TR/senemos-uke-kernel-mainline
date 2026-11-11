/* SPDX-License-Identifier: GPL-2.0-only
 * Actual kernel entry with controlled base/native-overlay callbacks. The fitted
 * wire helper and libfdt are real; this does not emulate hardware or full DPU.
 */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <setjmp.h>
#include <libfdt.h>
#define UKE_INIT
#define __init
#include "uke-audio-config-dt.h"
typedef uintptr_t phys_addr_t;
#define __pa_symbol(p) ((phys_addr_t)(uintptr_t)(p))
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define pr_crit(...) do { critical++; } while (0)
#define pr_warn(...) do { } while (0)
#define pr_info(...) do { } while (0)
#define cpu_relax() longjmp(refusal, 1)
static jmp_buf refusal;
static unsigned int critical, native_calls;
static int base_result, native_error;
static bool legacy;
static phys_addr_t physical;
_Alignas(8) static unsigned char uke_fdt[32768], input[32768], original[32768];
_Alignas(8) static unsigned char overlay_template[8192], overlay[8192];
static unsigned char uke_ufs_overlay[8], uke_usb_overlay[8], uke_lights_overlay[8];
struct uke_native_panel { void *overlay; size_t bytes; };
static const struct uke_native_panel uke_native_panels[] = {{ overlay, sizeof(overlay) }};
static int at(void *dt, const char *p) { int n=fdt_path_offset(dt,p); assert(n>=0); return n; }
static void child(void *dt, const char *parent, const char *name) { int ret=fdt_add_subnode(dt,at(dt,parent),name); if(ret<0) fprintf(stderr,"Fixture node %s/%s: %s (%d)\n",parent,name,fdt_strerror(ret),ret); assert(ret>=0); }
static void string(void *dt, const char *p, const char *name, const char *value) { assert(!fdt_setprop_string(dt,at(dt,p),name,value)); }
static void word(void *dt, const char *p, const char *name, uint32_t value) { assert(!fdt_setprop_u32(dt,at(dt,p),name,value)); }
static int uke_abl_transform(void *out, size_t capacity, const void *in, size_t bytes,
                            void *ufs, size_t ufs_bytes, void *usb, size_t usb_bytes)
{
 (void)bytes; (void)ufs; (void)ufs_bytes; (void)usb; (void)usb_bytes;
 if (base_result!=1) return base_result;
 int ret=fdt_open_into(in,out,capacity);
 /* The original production source called the helper in this earlier phase. */
#if EARLY_CONFIG
 if (!ret) ret=uke_audio_config_graph(out);
#endif
 if (!ret) ret=fdt_pack(out);
 return ret ? ret : 1;
}
static int uke_abl_native_select(void *dt, const struct uke_native_panel *panels, unsigned int count)
{
 native_calls++;
 assert(count==1 && panels[0].overlay==overlay);
 if (native_error) return native_error;
 int ret=legacy ? 0 : fdt_overlay_apply(dt,panels[0].overlay);
 /* Real native selection returns a packed tree: spare capacity is gone. */
 return ret ? ret : fdt_pack(dt);
}
static bool uke_lights_admitted(const void *dt) { (void)dt; return false; }
#include "entry.h"
static void reset(void)
{
 static const char compatibles[]="xiaomi,uke\0qcom,sm7675";
 memset(input,0,sizeof(input));memset(uke_fdt,0,sizeof(uke_fdt));
 assert(!fdt_create_empty_tree(input,sizeof(input)));
 assert(!fdt_setprop(input,0,"compatible",compatibles,sizeof(compatibles)));
 child(input,"/","soc");child(input,"/soc","iommu");
 word(input,"/soc/iommu","phandle",23);word(input,"/soc/iommu","#iommu-cells",2);
 child(input,"/soc","remoteproc-adsp@03000000");
 child(input,"/soc/remoteproc-adsp@03000000","glink-edge");
 child(input,"/soc/remoteproc-adsp@03000000/glink-edge","qcom,gpr");
 child(input,"/","unrelated");string(input,"/unrelated","sentinel","preserved");
 assert(!fdt_pack(input));memcpy(overlay,overlay_template,sizeof(overlay));
 base_result=1;native_error=0;legacy=false;critical=native_calls=0;
}
static void rejected(void)
{
 physical=0xfeed;
 memcpy(original,input,sizeof(input));
 if (!setjmp(refusal)) { (void)uke_abl_prepare_fdt(input,fdt_totalsize(input),&physical); assert(!"Invalid entry accepted"); }
 assert(critical==1 && physical==0xfeed && !memcmp(original,input,sizeof(input)));
}
int main(int argc,char **argv)
{
 assert(argc==2);
 FILE *f=fopen(argv[1],"rb");assert(f);
 size_t bytes=fread(overlay_template,1,sizeof(overlay_template),f);
 assert(bytes>0 && bytes<sizeof(overlay_template) && !ferror(f) && !fclose(f));
 assert(!fdt_check_full(overlay_template,bytes));
 reset();memcpy(original,input,sizeof(input));phys_addr_t physical=0xfeed;
 assert(!setjmp(refusal));
 void *result=uke_abl_prepare_fdt(input,fdt_totalsize(input),&physical);
 assert(result==uke_fdt && physical==(uintptr_t)uke_fdt && native_calls==1 && !critical);
 assert(!memcmp(original,input,sizeof(input)));
 int a,b;const void *one=fdt_getprop(uke_fdt,at(uke_fdt,UKE_CONFIG_FE),"iommus",&a);
 const void *two=fdt_getprop(uke_fdt,at(uke_fdt,"/audio-config-memory"),"iommus",&b);
 assert(one && two && a==24 && b==24 && !memcmp(one,two,24));
 assert(!fdt_check_full(uke_fdt,fdt_totalsize(uke_fdt)));
 assert(!strcmp(fdt_getprop(uke_fdt,at(uke_fdt,"/unrelated"),"sentinel",NULL),"preserved"));
 reset();legacy=true;physical=0xfeed;memcpy(original,input,sizeof(input));
 assert(uke_abl_prepare_fdt(input,fdt_totalsize(input),&physical)==uke_fdt);
 assert(fdt_path_offset(uke_fdt,"/audio-config-memory")==-FDT_ERR_NOTFOUND);
 assert(fdt_totalsize(input)==fdt_totalsize(uke_fdt));
 assert(!memcmp(input,uke_fdt,fdt_totalsize(input)));
 reset();base_result=0;physical=0xfeed;
 assert(uke_abl_prepare_fdt(input,fdt_totalsize(input),&physical)==input && physical==0xfeed && !native_calls);
 reset();base_result=-FDT_ERR_BADVALUE;rejected();
 reset();native_error=-FDT_ERR_BADVALUE;rejected();
 reset();word(input,"/soc/iommu","#iommu-cells",1);rejected();
 reset();assert(!fdt_open_into(input,input,sizeof(input)));child(input,"/","audio-config-memory");rejected();
 reset();assert(!fdt_open_into(overlay,overlay,sizeof(overlay)));
 assert(!fdt_delprop(overlay,at(overlay,"/fragment@0/__overlay__/service@1/dais"),"status"));rejected();
 puts("Actual Uke entry: late protected overlay, restored capacity, exact DMA supplier, immutable input, legacy/foreign handling and refused publication pass; controlled overlay callbacks only.");
 return 0;
}
