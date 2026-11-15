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
static unsigned int allocations,frees,sends,payload_bytes;
static bool no_memory;
static int response;
static unsigned char sent[236];
static void *audioreach_alloc_apm_cmd_pkt(unsigned int bytes,unsigned int opcode,unsigned int token) {
 assert((bytes==72||bytes==236) && opcode==APM_CMD_SET_CFG && !token);allocations++;
 if(no_memory)return (void *)(intptr_t)-ENOMEM;
 payload_bytes=bytes;return calloc(1,GPR_HDR_SIZE+APM_CMD_HDR_SIZE+bytes);
}
static void kfree(void *p) { assert(p && !IS_ERR(p));free(p);frees++; }
static int q6apm_send_cmd_sync(struct q6apm *apm,const struct gpr_pkt *pkt,int flags) {
 assert(apm && !flags);memset(sent,0xa5,sizeof(sent));
 memcpy(sent,(const unsigned char *)pkt+40,payload_bytes);sends++;return response;
}
#define EXPORT_SYMBOL_GPL(symbol)
#include "actual-q6apm-channel-ids.h"
#ifdef UKE_SURROUND_APM_HEADER
#include UKE_SURROUND_APM_HEADER
#else
#include "../src/audio/uke-speaker-quad-apm.h"
#endif
static unsigned int le16(const unsigned char *b) { return b[0]|b[1]<<8; }
static unsigned int le32(const unsigned char *b) { return le16(b)|le16(b+2)<<16; }
int main(void) {
 struct q6apm apm={};struct q6apm_graph graph={&apm};
 struct audioreach_module module={MODULE_ID_MFC,0x442e};
 const unsigned int ids[3][8]={{1,2,4,5},{1,2,4,5,3,6},{1,2,8,9,3,6,4,5}};
 const unsigned int weights6[4][6]={
  {8398,0,0,0,5938,2048},{0,8398,0,0,5938,2048},
  {0,0,14336,0,0,2048},{0,0,0,14336,0,2048}};
 const unsigned int weights8[4][8]={
  {8398,0,0,0,5938,2048,0,0},{0,8398,0,0,5938,2048,0,0},
  {0,0,7168,0,0,2048,7168,0},{0,0,0,7168,0,2048,0,7168}};
 unsigned int cases=0;
 for(unsigned int turn=0;turn<4;turn++) {
  unsigned char before[56];assert(!uke_quad_encode(before,sizeof(before),uke_quad_sources[turn]));
  assert(!audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[turn]));
  assert(payload_bytes==236 && le32(sent)==0x442e && le32(sent+4)==0x0800101f);
  assert(le32(sent+8)==220 && !le32(sent+12));
  const unsigned char *b=sent+16;assert(le32(b)==3);
  assert(!memcmp(b+4,before+4,52)); /* Existing four-channel table unchanged. */
  unsigned int offset=4;
  for(unsigned int t=0;t<3;t++) {
   const unsigned int n=4+t*2, coeff=4+(4+n)*2;
   const unsigned char *v=b+offset;
   assert(le16(v)==4 && le16(v+2)==n);
   for(unsigned int row=0;row<4;row++)assert(le16(v+4+row*2)==ids[0][row]);
   for(unsigned int col=0;col<n;col++)assert(le16(v+12+col*2)==ids[t][col]);
   for(unsigned int row=0;row<4;row++) {
    unsigned int sum=0;
    for(unsigned int col=0;col<n;col++) {
     const unsigned int value=le16(v+coeff+(row*n+col)*2);
     const unsigned int logical=uke_quad_sources[turn][row];
     const unsigned int expected=n==4?(logical==col?16384u:0u):
       n==6?weights6[logical][col]:weights8[logical][col];
     assert(value==expected && value<=16384);sum+=value;cases++;
    }
    /* All positive full-scale correlated inputs, including LFE: no peak gain. */
    assert(sum==16384);cases++;
   }
   for(unsigned int col=0;col<n;col++) {
    unsigned int sum=0;for(unsigned int row=0;row<4;row++)sum+=le16(v+coeff+(row*n+col)*2);
    assert(sum>0); /* No center, LFE, side or back input is dropped. */
    if(n>4 && col==5)assert(sum==8192);
    cases++;
   }
   offset+=coeff+4*n*2;
  }
  assert(offset==220);cases++;
  assert(!audioreach_uke_quad_matrix(&graph,&module,uke_quad_sources[turn]));
  assert(payload_bytes==72 && !memcmp(sent+16,before,56));cases++;
 }
 for(unsigned int n=0;n<229;n++)if(n!=220) {
  unsigned char bytes[228];memset(bytes,0xa5,sizeof(bytes));
  assert(uke_surround_encode(bytes,n,uke_quad_sources[0])==-EINVAL);
  for(unsigned int i=0;i<sizeof(bytes);i++)assert(bytes[i]==0xa5);
  cases++;
 }
 unsigned int old=sends;
 const unsigned int bad[4]={0,0,2,3};
 assert(uke_surround_encode(NULL,220,uke_quad_sources[0])==-EINVAL);cases++;
 assert(uke_surround_encode(sent,220,NULL)==-EINVAL);cases++;
 assert(audioreach_uke_surround_matrix(&graph,&module,bad)==-EINVAL);cases++;
 assert(audioreach_uke_surround_matrix(NULL,&module,uke_quad_sources[0])==-EINVAL);cases++;
 graph.apm=NULL;
 assert(audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[0])==-EINVAL);cases++;
 graph.apm=&apm;
 assert(audioreach_uke_surround_matrix(&graph,NULL,uke_quad_sources[0])==-EINVAL);cases++;
 module.instance_id=0x4040;
 assert(audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[0])==-EINVAL);cases++;
 module.instance_id=0x442e;module.module_id=0;
 assert(audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[0])==-EINVAL);cases++;
 module.module_id=MODULE_ID_MFC;assert(sends==old && allocations==frees);
 response=-ETIMEDOUT;
 assert(audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[1])==-ETIMEDOUT);cases++;
 response=1;assert(audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[2])==-EIO);cases++;
 no_memory=true;old=sends;
 assert(audioreach_uke_surround_matrix(&graph,&module,uke_quad_sources[3])==-ENOMEM && sends==old);cases++;
 assert(allocations==frees+1);
 printf("Actual surround MFC packet: %u layout/rotation/headroom/LFE/bounds/error cases passed; no firmware or physical acceptance.\n",cases);
}
