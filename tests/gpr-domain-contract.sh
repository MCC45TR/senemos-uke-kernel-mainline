#!/usr/bin/env bash
# Host-only fault controls for the actual APR/GPR domain-selection block.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
awk '/^#include <dt-bindings\/soc\/qcom,gpr.h>/ {print; found=1} END {if(!found) exit 1}' "$kernel/drivers/soc/qcom/apr.c"
cat <<'CPP'
#include <cassert>
#include <cstring>
#include <initializer_list>
#define EINVAL 22
#define PR_TYPE_GPR 1
#define PR_TYPE_APR 0
struct device_node { bool gpr, mainline; int mainline_ret, domain, cells, reg, legacy; };
struct device { device_node *of_node; };
struct packet_router { unsigned dest_domain_id; int type; };
bool uke;
bool of_machine_is_compatible(const char *s) { assert(!strcmp(s,"xiaomi,uke")); return uke; }
bool of_device_is_compatible(device_node *n,const char *s) { assert(!strcmp(s,"qcom,gpr")); return n && n->gpr; }
bool of_property_present(device_node *n,const char *s) { assert(!strcmp(s,"qcom,domain")); return n && n->mainline; }
int of_property_count_u32_elems(device_node *n,const char *s) { assert(!strcmp(s,"reg")); return n ? n->cells : -EINVAL; }
int of_property_read_u32(device_node *n,const char *s,unsigned *out) {
 if(!n) return -EINVAL;
 if(!strcmp(s,"qcom,domain")) { if(!n->mainline) return -EINVAL; if(n->mainline_ret) return n->mainline_ret; *out=n->domain; return 0; }
 if(!strcmp(s,"reg")) { if(n->cells != 1) return -EINVAL; *out=n->reg; return 0; }
 assert(!strcmp(s,"qcom,apr-domain")); if(n->legacy<0) return -EINVAL; *out=n->legacy; return 0;
}
#define dev_err(...) ((void)0)
int domain(device_node *node,packet_router *apr) {
 device d{node}; device *dev=&d; int ret;
CPP
awk '/^[[:space:]]*ret = of_property_read_u32\(dev->of_node, "qcom,domain"/ {emit=1}
     emit && /dev_set_drvdata\(dev, apr\)/ {exit}
     emit {print}' "$kernel/drivers/soc/qcom/apr.c"
cat <<'CPP'
 return 0;
}
int main() {
 packet_router apr{};
 device_node node{true,false,0,5,1,2,-1};
 uke=true;
 assert(domain(&node,&apr)==0 && apr.dest_domain_id==2 && apr.type==PR_TYPE_GPR);
 uke=false; assert(domain(&node,&apr)==-EINVAL);
 node.mainline=true; assert(domain(&node,&apr)==0 && apr.dest_domain_id==5);
 uke=true; assert(domain(&node,&apr)==0 && apr.dest_domain_id==5);
 node.mainline_ret=-EINVAL; assert(domain(&node,&apr)==-EINVAL);
 node.mainline=false; node.mainline_ret=0;
 for(int cells : {-EINVAL,0,2}) { node.cells=cells; assert(domain(&node,&apr)==-EINVAL); }
 node.cells=1;
 for(int id : {0,1,3,4,5,6}) { node.reg=id; assert(domain(&node,&apr)==-EINVAL); }
 node.reg=2; node.gpr=false; assert(domain(&node,&apr)==-EINVAL);
 node.legacy=4; assert(domain(&node,&apr)==0 && apr.dest_domain_id==4 && apr.type==PR_TYPE_APR);
 assert(domain(nullptr,&apr)==-EINVAL);
}
CPP
} > "$work/check.cpp"
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -I"$kernel/include" "$work/check.cpp" -o "$work/check"
"$work/check"
echo 'GPR domain: exact Uke OEM ADSP accepted; explicit properties preserved; malformed/foreign/APR/wrong-domain refused'
