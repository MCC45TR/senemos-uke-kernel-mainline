/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <limits.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
struct device { int unused; };
struct device_attribute { int unused; };
struct rproc { struct device dev; unsigned int crash_cnt; unsigned int state; };
#define to_rproc(p) ((struct rproc *)((char *)(p)-offsetof(struct rproc,dev)))
#define READ_ONCE(x) (x)
static int sysfs_emit(char *buf,const char *fmt,...) {
 va_list args;va_start(args,fmt);int count=vsnprintf(buf,4096,fmt,args);va_end(args);return count;
}
#include "rproc-crash-count-show.h"
int main(void) {
 const unsigned int counts[]={0,1,12,1000000,UINT_MAX};
 unsigned int cases=0;
 for(unsigned int state=0;state<3;state++)for(size_t i=0;i<sizeof(counts)/sizeof(counts[0]);i++) {
  struct rproc r={.crash_cnt=counts[i],.state=state},before=r;
  char buf[4096]={0},*end=NULL;
  ssize_t size=crash_count_show(&r.dev,NULL,buf);
  assert(size>0 && (size_t)size==strlen(buf) && buf[size-1]=='\n');
  assert(buf[0]>='0' && buf[0]<='9');
  assert(strtoul(buf,&end,10)==counts[i] && end==buf+size-1);
  assert(!memcmp(&r,&before,sizeof(r)));cases++;
 }
 printf("Actual remoteproc counter ABI: %u unsigned/read-only/recovered-state cases passed; controlled memory only.\n",cases);
 return 0;
}
