/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <libfdt.h>
#define UKE_INIT
#include "uke-audio-config-dt.h"
static unsigned char image[16384], before[16384];
static int path(const char *name) { int n=fdt_path_offset(image,name); assert(n>=0); return n; }
static void node(const char *parent,const char *name) { assert(fdt_add_subnode(image,path(parent),name)>=0); }
static void string(const char *p,const char *n,const char *v) { assert(!fdt_setprop_string(image,path(p),n,v)); }
static void word(const char *p,const char *n,unsigned int v) { assert(!fdt_setprop_u32(image,path(p),n,v)); }
static void reset(void)
{
	fdt32_t iommu[]={cpu_to_fdt32(23),cpu_to_fdt32(0x1001),cpu_to_fdt32(0x80),
		cpu_to_fdt32(23),cpu_to_fdt32(0x1061),0};
	static const char model[]="xiaomi,uke\0qcom,sm7675";
	memset(image,0,sizeof(image));
	assert(!fdt_create_empty_tree(image,sizeof(image)));
	assert(!fdt_setprop(image,0,"compatible",model,sizeof(model)));
	node("/","soc"); node("/soc","iommu");
	word("/soc/iommu","phandle",23); word("/soc/iommu","#iommu-cells",2);
	node("/soc","remoteproc-adsp@03000000");
	node("/soc/remoteproc-adsp@03000000","glink-edge");
	node("/soc/remoteproc-adsp@03000000/glink-edge","qcom,gpr");
	node("/soc/remoteproc-adsp@03000000/glink-edge/qcom,gpr","service@1");
	string(UKE_CONFIG_APM,"compatible","qcom,q6apm");
	assert(!fdt_setprop(image,path(UKE_CONFIG_APM),"xiaomi,fs19xx-protected","",0));
	node(UKE_CONFIG_APM,"dais");
	string(UKE_CONFIG_FE,"compatible","qcom,q6apm-dais");
	string(UKE_CONFIG_FE,"status","okay");
	assert(!fdt_setprop(image,path(UKE_CONFIG_FE),"iommus",iommu,sizeof(iommu)));
	node("/","unrelated"); string("/unrelated","sentinel","preserved");
}
static void refused(void)
{
	memcpy(before,image,sizeof(image));
	assert(uke_audio_config_graph(image)<0);
	assert(!memcmp(before,image,sizeof(image)));
}
int main(void)
{
	const void *a,*b; int na,nb;
	reset();
	assert(!uke_audio_config_graph(image));
	a=fdt_getprop(image,path(UKE_CONFIG_FE),"iommus",&na);
	b=fdt_getprop(image,path("/audio-config-memory"),"iommus",&nb);
	assert(a&&b&&na==24&&nb==24&&!memcmp(a,b,24));
	assert(!fdt_node_check_compatible(image,path("/audio-config-memory"),"xiaomi,uke-audio-config-memory"));
	assert(!strcmp(fdt_getprop(image,path("/unrelated"),"sentinel",NULL),"preserved"));
	const char *forbidden[]={"reg","memory-region","clocks","resets","dma-coherent","power-domains"};
	for(unsigned int i=0;i<sizeof(forbidden)/sizeof(*forbidden);i++)
		assert(!fdt_getprop(image,path("/audio-config-memory"),forbidden[i],NULL));
	refused(); /* Reapplication must not replace a different live supplier. */
	reset(); string("/","compatible","other,board"); refused();
	reset(); word(UKE_CONFIG_APM,"xiaomi,fs19xx-protected",1); refused();
	reset(); string(UKE_CONFIG_APM,"compatible","qcom,other"); refused();
	reset(); string(UKE_CONFIG_FE,"compatible","qcom,other"); refused();
	reset(); string(UKE_CONFIG_FE,"status","disabled"); refused();
	reset(); assert(!fdt_delprop(image,path(UKE_CONFIG_FE),"status")); refused();
	reset(); assert(!fdt_delprop(image,path(UKE_CONFIG_FE),"iommus")); refused();
	reset(); word("/soc/iommu","#iommu-cells",1); refused();
	for(int index=0;index<6;index++){
		fdt32_t property[6];
		reset(); a=fdt_getprop(image,path(UKE_CONFIG_FE),"iommus",&na);
		assert(a&&na==24); memcpy(property,a,24); property[index]^=cpu_to_fdt32(1);
		assert(!fdt_setprop(image,path(UKE_CONFIG_FE),"iommus",property,24)); refused();
	}
	reset(); node("/","audio-config-memory"); refused();
	reset(); assert(!fdt_delprop(image,path(UKE_CONFIG_APM),"xiaomi,fs19xx-protected"));
	memcpy(before,image,sizeof(image)); assert(!uke_audio_config_graph(image));
	assert(!memcmp(before,image,sizeof(image)));
	reset(); assert(!fdt_del_node(image,path(UKE_CONFIG_APM)));
	memcpy(before,image,sizeof(image)); assert(!uke_audio_config_graph(image));
	assert(!memcmp(before,image,sizeof(image)));
	reset(); assert(!fdt_pack(image));
	assert(uke_audio_config_graph(image)==-FDT_ERR_NOSPACE);
	puts("Actual Uke OOB DT: exact copied fitted contexts, preserved frontend/sentinel, legacy no-op, malformed/resource refusal and no-space failure passed; libfdt only.");
	return 0;
}
