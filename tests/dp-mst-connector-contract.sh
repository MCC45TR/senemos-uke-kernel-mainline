#!/usr/bin/env bash
# Execute the real MST constructor with allocation/property/encoder faults.
set -Eeuo pipefail
ulimit -c 0
source=${1:?Pass prepared dp_mst_drm.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/test.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <type_traits>
struct drm_connector;
struct drm_connector_funcs {void (*reset)(drm_connector*);};
struct drm_connector {struct {unsigned id;} base;void *state,*max_bpc_property;const drm_connector_funcs *funcs;};
struct drm_device {struct {void *path_property,*tile_property;} mode_config;};
struct drm_encoder {struct {unsigned id;} base;};
struct drm_dp_mst_port {unsigned refs;};
struct drm_dp_mst_topology_mgr {};
struct msm_dp {drm_device *drm_dev;drm_connector *connector;};
struct msm_dp_mst {drm_dp_mst_topology_mgr mst_mgr;struct msm_dp *msm_dp;unsigned max_streams;struct {drm_encoder *enc;} mst_encoders[2];};
struct msm_dp_mst_connector {drm_connector connector;msm_dp_mst *dp_mst;drm_dp_mst_port *mst_port;};
#define container_of(p,t,f) reinterpret_cast<t*>(reinterpret_cast<char*>(p)-offsetof(t,f))
#define drm_err(...) ((void)0)
#define drm_dbg_kms(...) ((void)0)
#define DRM_MODE_CONNECTOR_DisplayPort 1
static unsigned fault,allocations,cleanups,properties,encoders;
template<typename T> static T *allocate(){if(fault==1)return nullptr;++allocations;return static_cast<T*>(calloc(1,sizeof(T)));}
#define kzalloc_obj(o) allocate<std::remove_reference_t<decltype(o)>>()
static void kfree(void *p){assert(allocations);--allocations;free(p);}
static void reset(drm_connector *c){if(fault!=3)c->state=calloc(1,1);}
static const drm_connector_funcs msm_dp_drm_mst_connector_funcs{reset};
static const int msm_dp_drm_mst_connector_helper_funcs=0;
static int drm_connector_dynamic_init(drm_device*,drm_connector *c,const drm_connector_funcs *f,int type,void*){
 assert(type==DRM_MODE_CONNECTOR_DisplayPort);c->funcs=f;return fault==2?-ENOMEM:0;
}
static void drm_connector_helper_add(drm_connector*,const int*){}
static int drm_connector_attach_max_bpc_property(drm_connector *c,unsigned a,unsigned b){
 assert(c->state&&a==8&&b==10);++properties;return fault==4?-ENOMEM:0;
}
static int drm_connector_attach_encoder(drm_connector*,drm_encoder*){++encoders;return fault==5?-ENOMEM:0;}
static void drm_dp_mst_get_port_malloc(drm_dp_mst_port *p){++p->refs;}
static void drm_dp_mst_put_port_malloc(drm_dp_mst_port *p){assert(p->refs>1);--p->refs;}
static void drm_object_attach_property(void*,void*,int){}
static int drm_connector_set_path_property(drm_connector*,const char*){return fault==6?-ENOMEM:0;}
static void drm_connector_cleanup(drm_connector *c){++cleanups;free(c->state);c->state=nullptr;}
CPP
awk '/^msm_dp_mst_add_connector\(/ {print previous;emit=1;found=1} emit{print} emit&&/^}/{exit} {previous=$0} END{if(!found)exit 1}' "$source" >> "$work/test.cpp"
cat >> "$work/test.cpp" <<'CPP'
int main(){
 for(fault=0;fault<=6;fault++){
  allocations=cleanups=properties=encoders=0;drm_device dev{};int property;drm_connector root{};root.max_bpc_property=&property;
  msm_dp dp{&dev,&root};drm_encoder encoder{};msm_dp_mst mst{{},&dp,1,{{&encoder},{}}};drm_dp_mst_port port{1};
  auto *result=msm_dp_mst_add_connector(&mst.mst_mgr,&port,"mst:1-1");
  if(!fault){assert(result&&result->state&&port.refs==2&&allocations==1&&properties==1&&encoders==1);
   drm_connector_cleanup(result);drm_dp_mst_put_port_malloc(&port);kfree(container_of(result,msm_dp_mst_connector,connector));
  }else{assert(!result&&port.refs==1&&!allocations);assert(cleanups==(fault>=3?1U:0U));
   if(fault==3)assert(!properties&&!encoders);
   if(fault==4)assert(properties==1&&!encoders);
  }
 }
 puts("Production MST constructor: allocation/reset OOM, max-bpc/encoder/path errors, cleanup and port reference balance: PASS; host only.");
}
CPP
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-sign-compare -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/test.cpp" -o "$work/test"
"$work/test"
