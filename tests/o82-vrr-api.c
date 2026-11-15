/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct kernel_param { void *arg; };
struct kernel_param_ops {
 int (*set)(const char *,const struct kernel_param *);
 int (*get)(char *,const struct kernel_param *);
};
static int param_set_uint(const char *text,const struct kernel_param *p)
{
 char *end;errno=0;unsigned long n=strtoul(text,&end,0);
 if(errno||end==text||*end||*text=='-'||n>UINT_MAX)return -EINVAL;
 *(unsigned int *)p->arg=n;return 0;
}
static int param_get_uint(char *text,const struct kernel_param *p)
{return snprintf(text,32,"%u\n",*(unsigned int *)p->arg);}
#define module_param_cb(name,ops,arg,mode) \
 static const struct kernel_param_ops *name##_ops=ops; \
 static const struct kernel_param name##_parameter={arg}; \
 static const unsigned name##_permissions=mode
#define __MODULE_PARM_TYPE(name,type) static const char name##_type[]=type
#define MODULE_PARM_DESC(name,text)
#include "actual-vrr-api.inc"
int main(void)
{
 char text[32];unsigned cases=0;
 assert(o82_vrr_floor_api==1&&o82_vrr_test_min_hz==0);cases++;
 assert(o82_vrr_floor_api_permissions==0444&&!o82_vrr_floor_api_ops->set);cases++;
 assert(o82_vrr_floor_api_ops->get(text,&o82_vrr_floor_api_parameter)>0&&!strcmp(text,"1\n"));cases++;
 assert(!strcmp(o82_vrr_floor_api_type,"uint")&&!strcmp(o82_vrr_test_min_hz_type,"uint"));cases++;
 assert(o82_vrr_test_min_hz_permissions==0400&&o82_vrr_test_min_hz_ops->set);cases++;
 for(unsigned n=0;n<200;n++){
  snprintf(text,sizeof(text),"%u",n);unsigned before=o82_vrr_test_min_hz;
  int ret=o82_vrr_test_min_hz_ops->set(text,&o82_vrr_test_min_hz_parameter);
  if(n&&(n<30||n>=144))assert(ret==-ERANGE&&o82_vrr_test_min_hz==before);
  else assert(!ret&&o82_vrr_test_min_hz==n);
  assert(o82_vrr_floor_api==1&&!o82_vrr_floor_api_ops->set);cases++;
 }
 assert(!o82_vrr_test_min_hz_ops->set("0",&o82_vrr_test_min_hz_parameter));
 assert(o82_vrr_test_min_hz_ops->set("invalid",&o82_vrr_test_min_hz_parameter)<0&&!o82_vrr_test_min_hz);cases++;
 assert(o82_vrr_test_min_hz_ops->set("4294967296",&o82_vrr_test_min_hz_parameter)<0&&!o82_vrr_test_min_hz);cases++;
 printf("Actual O82 VRR ABI: %u cases, fixed read-only ABI1, both uint metadata, unchanged zero/default and transactional floor admission passed; no display operation.\n",cases);
}
