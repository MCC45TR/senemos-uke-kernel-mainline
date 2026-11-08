/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
struct q6apm { int unused; };
struct q6apm_graph { struct q6apm *apm; };
struct audioreach_module { unsigned int module_id,instance_id; };
struct gpr_pkt { unsigned char header[24]; };
struct apm_module_param_data { uint32_t module_instance_id,param_id,param_size,error_code; };
#define GPR_HDR_SIZE 24
#define APM_CMD_HDR_SIZE 16
#define APM_MODULE_PARAM_DATA_SIZE 16
#define MODULE_ID_MFC 0x07001015
#define APM_CMD_SET_CFG 0x01001006
#define IS_ERR(p) ((uintptr_t)(p)>(uintptr_t)-4096)
#define PTR_ERR(p) ((int)(intptr_t)(p))
static unsigned int allocations,frees,sends;
static bool no_memory;
static int response;
static unsigned char sent[72];
static void *audioreach_alloc_apm_cmd_pkt(unsigned int bytes,unsigned int opcode,unsigned int token) {
 assert(bytes==72 && opcode==APM_CMD_SET_CFG && !token);allocations++;
 if(no_memory)return (void *)(intptr_t)-ENOMEM;
 return calloc(1,GPR_HDR_SIZE+APM_CMD_HDR_SIZE+bytes);
}
static void kfree(void *p) { assert(p && !IS_ERR(p));free(p);frees++; }
static int q6apm_send_cmd_sync(struct q6apm *apm,const struct gpr_pkt *pkt,int flags) {
 assert(apm && !flags);memcpy(sent,(const unsigned char *)pkt+40,sizeof(sent));sends++;return response;
}
#define EXPORT_SYMBOL_GPL(symbol)
#include "../src/audio/uke-speaker-quad-apm.h"
static unsigned int le16(const unsigned char *b) { return b[0]|b[1]<<8; }
static unsigned int le32(const unsigned char *b) { return le16(b)|le16(b+2)<<16; }
int main(void) {
 struct q6apm apm={};struct q6apm_graph graph={&apm};
 struct audioreach_module module={MODULE_ID_MFC,0x442e};
 const unsigned int ids[4]={1,2,5,6};unsigned int cases=0;
 for(unsigned int turn=0;turn<4;turn++) {
  assert(!audioreach_uke_quad_matrix(&graph,&module,uke_quad_sources[turn]));
  assert(le32(sent)==0x442e && le32(sent+4)==0x0800101f && le32(sent+8)==56 && !le32(sent+12));
  const unsigned char *b=sent+16;
  assert(le32(b)==1 && le16(b+4)==4 && le16(b+6)==4);
  for(unsigned int row=0;row<4;row++) {
   assert(le16(b+8+row*2)==ids[row] && le16(b+16+row*2)==ids[row]);
   unsigned int sum=0;
   for(unsigned int col=0;col<4;col++) {
    unsigned int value=le16(b+24+(row*4+col)*2);sum+=value;
    assert(value==(uke_quad_sources[turn][row]==col?16384u:0u));
   }
   assert(sum==16384);cases++;
  }
  for(unsigned int col=0;col<4;col++) {
   unsigned int sum=0;for(unsigned int row=0;row<4;row++)sum+=le16(b+24+(row*4+col)*2);
   assert(sum==16384);cases++;
  }
 }
 for(unsigned int n=0;n<56;n++) {
  unsigned char bytes[56];memset(bytes,0xa5,sizeof(bytes));
  assert(uke_quad_encode(bytes,n,uke_quad_sources[0])==-EINVAL);
  for(unsigned int i=0;i<56;i++)assert(bytes[i]==0xa5);
  cases++;
 }
 assert(allocations==frees && sends==4);
 response=-ETIMEDOUT;assert(audioreach_uke_quad_matrix(&graph,&module,uke_quad_sources[1])==-ETIMEDOUT);cases++;
 response=1;assert(audioreach_uke_quad_matrix(&graph,&module,uke_quad_sources[2])==-EIO);cases++;
 no_memory=true;unsigned int before=sends;
 assert(audioreach_uke_quad_matrix(&graph,&module,uke_quad_sources[3])==-ENOMEM && sends==before);cases++;
 module.instance_id=0x4040;assert(audioreach_uke_quad_matrix(&graph,&module,uke_quad_sources[0])==-EINVAL);cases++;
 assert(allocations==frees+1);
 printf("Actual quad coefficient packet: %u fixed-identity/unit-gain/bounds/error cases passed; controlled GPR only.\n",cases);
}
