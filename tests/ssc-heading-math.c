/* SPDX-License-Identifier: GPL-2.0-only OR MIT */
#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "uke-ssc-heading.h"

static unsigned long checks;
static double worst;
static void compare(const s64 q[4])
{
 s32 result = -1, reversed = -1;
 s64 inverse[4];
 double norm = 0, expected, delta;
 int i;
 for(i=0;i<4;i++){norm+=(double)q[i]*q[i];inverse[i]=-q[i];}
 expected=atan2(2.0*((double)q[0]*q[1]-(double)q[2]*q[3]),norm-2.0*((double)q[0]*q[0]+(double)q[2]*q[2]))*180.0/acos(-1.0);
 if(expected<0)expected+=360;
 assert(uke_ssc_heading_microdegrees(q,&result)==0);
 assert(result>=0&&result<360000000);
 assert(uke_ssc_heading_microdegrees(inverse,&reversed)==0&&reversed==result);
 delta=fabs(expected-(double)result/1000000.0);if(delta>180)delta=360-delta;
 if(delta>worst)worst=delta;
 assert(delta<0.0002);
 checks++;
}
int main(void)
{
 const s64 known[][4]={{0,0,0,1000000},{0,0,-707107,707107},{0,0,1000000,0},{0,0,707107,707107}};
 const s32 cardinal[]={0,90000000,180000000,270000000};
 s64 q[4];s32 output;int yaw,pitch,roll,i,scale;
 for(i=0;i<4;i++){output=-1;assert(uke_ssc_heading_microdegrees(known[i],&output)==0);assert(abs(output-cardinal[i])<=2);compare(known[i]);}
 for(yaw=0;yaw<360;yaw+=3)for(pitch=-75;pitch<=75;pitch+=15)for(roll=-60;roll<=60;roll+=20){
  double a=-yaw*acos(-1.0)/360.0,b=pitch*acos(-1.0)/360.0,c=roll*acos(-1.0)/360.0;
  double x=cos(a)*sin(b)*cos(c)+sin(a)*cos(b)*sin(c);
  double y=cos(a)*cos(b)*sin(c)-sin(a)*sin(b)*cos(c);
  double z=sin(a)*cos(b)*cos(c)-cos(a)*sin(b)*sin(c);
  double w=cos(a)*cos(b)*cos(c)+sin(a)*sin(b)*sin(c);
  for(scale=996000;scale<=1004000;scale+=4000){q[0]=llround(x*scale);q[1]=llround(y*scale);q[2]=llround(z*scale);q[3]=llround(w*scale);compare(q);}
 }
 output=123;assert(uke_ssc_heading_microdegrees(NULL,&output)==-EINVAL&&output==123);assert(uke_ssc_heading_microdegrees(known[0],NULL)==-EINVAL);
 const s64 bad[][4]={{0,0,0,0},{0,0,0,500000},{1000000,1000000,1000000,1000000},{LLONG_MAX,0,0,0},{LLONG_MIN,0,0,0},{0,0,0,1000001},{0,0,0,1010000}};
 for(i=0;i<(int)(sizeof(bad)/sizeof(bad[0]));i++){output=123;assert(uke_ssc_heading_microdegrees(bad[i],&output)==-ERANGE&&output==123);}
 const s64 vertical[4]={707107,0,0,707107};output=123;assert(uke_ssc_heading_microdegrees(vertical,&output)==-ENODATA&&output==123);
 printf("Actual integer heading: %lu unit/sign/tilt/scale cases; maximum error %.9f degree; invalid/overflow/vertical refusal; no physical acceptance.\n",checks,worst);
 return 0;
}
