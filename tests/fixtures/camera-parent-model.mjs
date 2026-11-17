// SPDX-License-Identifier: GPL-2.0-only
// Adapt the qualified framework models; production function bodies stay intact.
import fs from 'node:fs';
const [kind,input,output]=process.argv.slice(2);
let s=fs.readFileSync(input,'utf8');
function edit(a,b){if(s.split(a).length!==2)throw Error('model anchor: '+a);s=s.replace(a,b);}
if(kind==='constructor'){
 edit('static int cam_cc_crm_passive[30];',`struct clk_alpha_pll {struct clk_regmap clkr;};
enum {CAM_CC_CRM_PLL,CAM_CC_CRM_BRANCH};
static struct clk_alpha_pll modeled_plls[2];
static struct {struct clk_regmap *clock;unsigned kind;} cam_cc_crm_passive[30];
static unsigned catalog_checks,parent_preparations,direct_preparations;
static int catalog_error,parent_error;`);
 edit('static int cam_cc_crm_rom_load(',`static int cam_cc_crm_passive_catalog_preflight(void)
{
 assert(!strcmp(phase,"crm-native-plls") && !reads && !rom_calls && !binds && !attaches);
 catalog_checks++;return catalog_error;
}
static int cam_cc_native_plls_configure_except(bool (*skip)(struct clk_alpha_pll *))
{
 assert(catalog_checks==1 && !reads && !rom_calls && !binds && !attaches);
 assert(cam_cc_native.probe_pm_held && cam_cc_native.proxy_votes==7 && !cam_cc_power.publication_started);
 assert(skip && skip(&modeled_plls[0]) && !skip(&modeled_plls[1]));
 parent_preparations++;return parent_error;
}
static int cam_cc_native_plls_configure(void)
{ direct_preparations++;return parent_error; }
static int cam_cc_crm_rom_load(`);
 edit('u32 a,b;rom_calls++;','u32 a,b;assert(parent_preparations==1);rom_calls++;');
 edit('changed_startup=changed_caps=false;phase=NULL;',`changed_startup=changed_caps=false;phase=NULL;
 memset(cam_cc_crm_passive,0,sizeof(cam_cc_crm_passive));
 cam_cc_crm_passive[0].kind=CAM_CC_CRM_PLL;
 cam_cc_crm_passive[0].clock=&modeled_plls[0].clkr;
 catalog_checks=parent_preparations=direct_preparations=0;catalog_error=parent_error=0;`);
 edit(' puts("PASS: camera native composition:',`#ifndef UKE_PARENT_BEFORE
 reset();assert(cam_cc_crm_native_plls_finalize()==-EINVAL && !parent_preparations && !direct_preparations);
 reset();assert(!cam_cc_crm_native_admit());assert(!cam_cc_crm_native_plls_finalize());
 assert(parent_preparations==1 && !direct_preparations);
 cam_cc_power.fault=-EIO;assert(cam_cc_crm_native_plls_finalize()==-EIO && parent_preparations==1);
 reset();cam_cc_crm_guard.firmware_enabled=false;assert(!cam_cc_crm_native_plls_finalize() && direct_preparations==1);
 reset();catalog_error=-EINVAL;assert(cam_cc_crm_native_admit()==-EINVAL && !parent_preparations && !rom_calls && !binds);
 reset();parent_error=-EREMOTEIO;assert(cam_cc_crm_native_admit()==-EREMOTEIO && parent_preparations==1 && !rom_calls && !binds);
 for(unsigned i=0;i<5;i++){
  reset();switch(i){case 0:cam_cc_clocks_ready=false;break;case 1:cam_cc_crm_guard.checked=false;break;
  case 2:cam_cc_crm_guard.owned=false;break;case 3:cam_cc_crmc_resource.owned=false;break;default:cam_cc_power.publication_started=true;}
  assert(cam_cc_crm_native_admit()==-EINVAL && !catalog_checks && !parent_preparations && !rom_calls && !binds);
 }
 puts("PASS: camera parent constructor: native parents precede ROM, exact firmware predicate, early failure blocks reads/binding, finalize once, original direct path");
#endif
 puts("PASS: camera native composition:`);
 s='#define pr_err(...) do { if (0) fprintf(stderr,__VA_ARGS__); } while (0)\n'+s;
}else if(kind==='handoff'){
 edit('#include "native-registration.h"',`static unsigned finalize_calls;
static int cam_cc_crm_native_plls_finalize(void)
{ finalize_calls++;return cam_cc_native_plls_configure(); }
#include "native-registration.h"`);
 edit('int main(void)','static int legacy_main(void)');
 s+=`
static bool skip_firmware_pll(struct clk_alpha_pll *pll) {return pll==&plls[1];}
static void setup_parent(void)
{
 defaults(false);model_device.dev.active=true;assert(!cam_cc_clocks_init());
 model_map.words[(plls[1].offset+pll_regs[PLL_OFF_L_VAL])/4]=0x1234;
 model_map.words[(plls[1].offset+pll_regs[PLL_OFF_USER_CTL])/4]=CAM_CC_PLL_FSM;
}
int main(void)
{
 assert(!legacy_main());
 setup_parent();int parent_start=steps;assert(!cam_cc_native_plls_configure_except(skip_firmware_pll));
 assert(configured_plls==1 && model_map.words[pll_regs[PLL_OFF_L_VAL]/4]==62);
 assert(model_map.words[(plls[1].offset+pll_regs[PLL_OFF_L_VAL])/4]==0x1234);
 int parent_steps=steps-parent_start;
 for(int n=1;n<=parent_steps;n++){
  setup_parent();fail_at=steps+n;assert(cam_cc_native_plls_configure_except(skip_firmware_pll)<0);
  assert(model_map.words[(plls[1].offset+pll_regs[PLL_OFF_L_VAL])/4]==0x1234);
 }
 setup_parent();model_map.words[pll_regs[PLL_OFF_USER_CTL]/4]=CAM_CC_PLL_FSM;
 assert(cam_cc_native_plls_configure_except(skip_firmware_pll)==-EOPNOTSUPP && !configured_plls);
 setup_parent();plls[0].config=NULL;assert(cam_cc_native_plls_configure_except(skip_firmware_pll)==-EINVAL && !configured_plls);
 defaults(true);model_device.dev.active=true;assert(!cam_cc_clocks_init());
 assert(!cam_cc_native_plls_configure_except(skip_firmware_pll) && !configured_plls);
 defaults(false);model_device.dev.active=true;assert(!cam_cc_clocks_init());
 assert(!cam_cc_native_plls_configure() && configured_plls==2);
 unsigned old_finalize=finalize_calls;defaults(false);assert(!cam_cc_native_probe(&model_device));
 assert(finalize_calls==old_finalize+1);
 puts("PASS: camera parent PLL: managed FSM/contents untouched, native programming/readback, read/write faults, FSM/config refusal, inherited running parent, direct path and actual caller");
 return 0;
}
`;
}else throw Error('model kind');
fs.writeFileSync(output,s);
