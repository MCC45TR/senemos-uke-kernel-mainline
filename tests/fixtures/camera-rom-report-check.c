/* SPDX-License-Identifier: GPL-2.0-only */
/* Compile the production reporter; no hardware or clock framework exists here. */
#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef uint32_t u32;
typedef uint64_t u64;
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define CAM_CC_CRM_LEVELS 7
static struct {
	struct {u64 hz; u32 source;} rates[7];
	u32 count;
} cam_cc_crm_native_tables[8];
static struct {
	u32 offsets[14], values[14], count;
} cam_cc_crm_native_rom_words[8];
static char output[8192];
static size_t used;
static unsigned lines;
static void pr_err(const char *format, ...) __attribute__((format(printf,1,2)));
static void pr_err(const char *format, ...)
{
	va_list args;
	va_start(args,format);
	int n=vsnprintf(output+used,sizeof(output)-used,format,args);
	va_end(args);
	assert(n>=0 && (size_t)n<sizeof(output)-used);
	used+=(size_t)n;lines++;
}
#include "rom-report.h"
static void reset(void) {used=lines=0;memset(output,0,sizeof(output));}
int main(void)
{
	for(unsigned client=0;client<8;client++) {
		cam_cc_crm_native_rom_words[client].count=14;
		cam_cc_crm_native_tables[client].count=7;
		for(unsigned i=0;i<14;i++) {
			cam_cc_crm_native_rom_words[client].offsets[i]=0x114+client*0x200+i*4;
			cam_cc_crm_native_rom_words[client].values[i]=0xffffffffU-i;
		}
		for(unsigned i=0;i<7;i++) {
			cam_cc_crm_native_tables[client].rates[i].hz=~(u64)0-i;
			cam_cc_crm_native_tables[client].rates[i].source=7;
		}
	}
	unsigned char words[sizeof(cam_cc_crm_native_rom_words)];
	unsigned char tables[sizeof(cam_cc_crm_native_tables)];
	memcpy(words,cam_cc_crm_native_rom_words,sizeof(words));
	memcpy(tables,cam_cc_crm_native_tables,sizeof(tables));
	for(unsigned client=0;client<8;client++) {
		reset();
		assert(cam_cc_crm_rom_report(client,"voltage",7,-EINVAL)==-EINVAL);
		assert(lines==23 && used<4096 && strstr(output,"stage=voltage"));
		assert(strstr(output,"18446744073709551615"));
		assert(!memcmp(words,cam_cc_crm_native_rom_words,sizeof(words)));
		assert(!memcmp(tables,cam_cc_crm_native_tables,sizeof(tables)));
	}
	reset();assert(cam_cc_crm_rom_report(8,NULL,0,-EREMOTEIO)==-EREMOTEIO);
	assert(lines==1 && strstr(output,"stage=unknown"));
	reset();cam_cc_crm_native_rom_words[0].count=15;
	assert(cam_cc_crm_rom_report(0,"load",0,-EOVERFLOW)==-EOVERFLOW && lines==2);
	reset();cam_cc_crm_native_rom_words[0].count=0;
	cam_cc_crm_native_tables[0].count=8;
	assert(cam_cc_crm_rom_report(0,"load",0,-EINVAL)==-EINVAL && lines==2);
	reset();cam_cc_crm_native_tables[0].count=0;
	assert(cam_cc_crm_rom_report(0,"load",0,-EINVAL)==-EINVAL && lines==2);
	puts("PASS: camera ROM reporter: eight clients, bounded cached output, unchanged errno/data and invalid-count refusal");
	return 0;
}
