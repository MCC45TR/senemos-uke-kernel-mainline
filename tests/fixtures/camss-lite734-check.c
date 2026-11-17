// SPDX-License-Identifier: GPL-2.0-only
/* Actual production callbacks, modeled MMIO, independent GPL OEM register oracle. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
typedef uint8_t u8;
typedef uint32_t u32;
#define BIT(n) (1U << (n))
#define ALIGN(n,a) (((n)+(a)-1)&~((a)-1))
#define dev_dbg(...) do {} while (0)
enum { CAMSS_7675, CAMSS_8550, CAMSS_8650, CAMSS_8775P, CAMSS_8300 };
struct camss_resources { unsigned version; };
struct camss { const struct camss_resources *res; void *dev; };
struct vfe_device { struct camss *camss; void *base; bool lite; };
static bool vfe_is_lite(struct vfe_device *vfe) { return vfe->lite; }
struct v4l2_pix_format_mplane { u32 height; struct {u32 bytesperline;} plane_fmt[1]; };
struct vfe_line { struct {struct {struct {struct v4l2_pix_format_mplane pix_mp;} fmt;} active_fmt;} video_out; };
struct write { u32 offset, value; };
static unsigned char registers[0x4000];
static struct write writes[32];
static size_t nwrites;
static void record_write(u32 value, void *address)
{
	ptrdiff_t offset = (unsigned char *)address-registers;
	assert(offset>=0 && offset<(ptrdiff_t)sizeof(registers) && !(offset&3));
	assert(nwrites<sizeof(writes)/sizeof(writes[0]));
	writes[nwrites++] = (struct write){(u32)offset,value};
}
#define writel(value,address) record_write((value),(address))
#include "actual-vfe-functions.h"
struct oracle_row {
	u32 cfg, image_addr, frame_incr, image_cfg_0, image_cfg_2, packer_cfg;
	u32 irq_subsample_period, irq_subsample_pattern;
	u32 mmu_prefetch_cfg, mmu_prefetch_max_offset;
};
#include "actual-oem-oracle.h"

static struct vfe_line make_line(u32 stride,u32 height)
{
	struct vfe_line line={0};
	line.video_out.active_fmt.fmt.pix_mp.height=height;
	line.video_out.active_fmt.fmt.pix_mp.plane_fmt[0].bytesperline=stride;
	return line;
}
static void run_trace(unsigned version,bool lite,u8 rdi,u32 stride,u32 height,u32 addr)
{
	const struct camss_resources res={version};
	struct camss camss={&res,NULL};
	struct vfe_device vfe={&camss,registers,lite};
	struct vfe_line line=make_line(stride,height);
	nwrites=0;
	vfe_wm_start(&vfe,rdi,&line);
	vfe_wm_update(&vfe,rdi,addr,&line);
	vfe_wm_stop(&vfe,rdi);
}
static void expect_write(size_t index,u32 offset,u32 value)
{
	assert(index<nwrites);
	if(writes[index].offset!=offset || writes[index].value!=value) {
		fprintf(stderr,"OEM trace mismatch index=%zu offset=%#x expected=%#x value=%#x expected-value=%#x\n",
			index,writes[index].offset,offset,writes[index].value,value);
		assert(false);
	}
}
static unsigned test_sm7675_lite(void)
{
	static const u32 strides[]={256,3840,8192},heights[]={1,1080},addresses[]={0x1000,0x7fffff00,0xffffff00};
	unsigned count=0;
	for(u8 rdi=0;rdi<4;rdi++)for(unsigned s=0;s<3;s++)for(unsigned h=0;h<2;h++)for(unsigned a=0;a<3;a++) {
		const struct oracle_row *o=&oem_rdi[rdi];
		u32 base=OEM_VFE_ORIGIN;
		run_trace(CAMSS_7675,true,rdi,strides[s],heights[h],addresses[a]);
		assert(nwrites==13);
		expect_write(0,OEM_CGC-base,0x7ffffff);
		expect_write(1,OEM_TEST_BUS-base,0);
		expect_write(2,o->frame_incr-base,((strides[s]+15)&~15U)*heights[h]>>8);
		expect_write(3,o->image_cfg_0-base,0xffff);
		expect_write(4,o->image_cfg_2-base,0xffff);
		expect_write(5,o->packer_cfg-base,0);
		expect_write(6,o->irq_subsample_period-base,0);
		expect_write(7,o->irq_subsample_pattern-base,1);
		expect_write(8,o->mmu_prefetch_cfg-base,1);
		expect_write(9,o->mmu_prefetch_max_offset-base,UINT32_MAX);
		expect_write(10,o->cfg-base,0x10001);
		expect_write(11,o->image_addr-base,addresses[a]/256);
		expect_write(12,o->cfg-base,0);
		count++;
	}
	return count;
}
static void print_legacy_traces(void)
{
	for(unsigned version=0;version<5;version++)for(unsigned lite=0;lite<2;lite++) {
		if(version==CAMSS_7675 && lite)continue;
		for(u8 rdi=0;rdi<(lite?4:3);rdi++) {
			run_trace(version,lite,rdi,3840,1080,0x12345600);
			printf("case %u %u %u %zu\n",version,lite,rdi,nwrites);
			for(size_t i=0;i<nwrites;i++)printf("%08x %08x\n",writes[i].offset,writes[i].value);
		}
	}
}
int main(int argc,char **argv)
{
	if(argc==2 && !strcmp(argv[1],"--legacy")){print_legacy_traces();return 0;}
	assert(argc==1);
	printf("PASS: CAMSS SM7675 lite: %u complete start/update/stop traces match independent OEM tables; no hardware\n",test_sm7675_lite());
	return 0;
}
