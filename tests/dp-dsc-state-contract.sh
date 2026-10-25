#!/usr/bin/env bash
# Actual policy/getter functions with synthetic atomic states; no device access.
set -Eeuo pipefail
source=${1:?Pass prepared dp_display.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/test.cpp" <<'CPP'
#include <cassert>
#include <cstddef>
#include <cerrno>
#include <cstring>
#include <sys/types.h>
struct drm_dsc_config { unsigned bits_per_pixel; };
struct msm_dp_dsc_config { drm_dsc_config dsc; };
struct drm_bridge_state {};
struct drm_bridge {};
struct msm_dp_bridge_state { drm_bridge_state base; msm_dp_dsc_config dsc; };
struct drm_atomic_commit { drm_bridge_state *bridge; };
struct device { void *data,*of_node; };
struct device_attribute {};
struct platform_device { device dev; };
struct msm_dp { bool is_edp,power_on; platform_device *pdev; drm_bridge *bridge; };
struct msm_dp_panel { bool dsc_requested; msm_dp_dsc_config dsc; };
struct msm_dp_display_private {
 msm_dp msm_dp_display; msm_dp_panel *panel;
 bool plugged_lock,plugged,stream_pm_active,stream_link_attempted;
};
#define container_of(p,type,field) reinterpret_cast<type*>(reinterpret_cast<char*>(p)-offsetof(type,field))
#define to_dp_bridge_state(p) container_of(p,msm_dp_bridge_state,base)
#define READ_ONCE(value) (value)
struct Guard { bool *lock; explicit Guard(bool *p):lock(p){assert(!*p);*p=true;} ~Guard(){assert(*lock);*lock=false;} };
#define guard(type) Guard held
static msm_dp_display_private *dev_get_dp_display_private(device *dev) {return static_cast<msm_dp_display_private*>(dev->data);}
static int kstrtobool(const char *text,bool *value) {
 if(!strcmp(text,"1\n")){*value=true;return 0;}
 if(!strcmp(text,"0\n")){*value=false;return 0;}
 return -EINVAL;
}
static bool compatible=true;
static bool of_device_is_compatible(void*,const char*) {return compatible;}
static drm_bridge_state *drm_atomic_get_new_bridge_state(drm_atomic_commit *state,drm_bridge*) {return state->bridge;}
CPP
awk '/^static ssize_t uke_dp_dsc_store\(/ || /^struct drm_dsc_config \*msm_dp_get_dsc_config\(/ {emit=1}
 emit{print} emit&&/^}/{emit=0}' "$source" >> "$work/test.cpp"
cat >> "$work/test.cpp" <<'CPP'
int main() {
 platform_device pdev{}; drm_bridge bridge; msm_dp_panel panel{};
 msm_dp_display_private dp{}; dp.panel=&panel;
 dp.msm_dp_display.pdev=&pdev; dp.msm_dp_display.bridge=&bridge; device dev{&dp,nullptr};
 assert(uke_dp_dsc_store(&dev,nullptr,"bad",3)==-EINVAL && !panel.dsc_requested && !dp.plugged_lock);
 for(unsigned condition=0;condition<4;condition++) {
  dp.plugged=condition==0;dp.msm_dp_display.power_on=condition==1;
  dp.stream_pm_active=condition==2;dp.stream_link_attempted=condition==3;
  assert(uke_dp_dsc_store(&dev,nullptr,"1\n",2)==-EBUSY && !panel.dsc_requested && !dp.plugged_lock);
 }
 dp.plugged=dp.msm_dp_display.power_on=dp.stream_pm_active=dp.stream_link_attempted=false;
 assert(uke_dp_dsc_store(&dev,nullptr,"1\n",2)==2 && panel.dsc_requested && !dp.plugged_lock);
 assert(!msm_dp_get_dsc_config(&dp.msm_dp_display,nullptr));
 panel.dsc.dsc.bits_per_pixel=128;
 assert(msm_dp_get_dsc_config(&dp.msm_dp_display,nullptr)==&panel.dsc.dsc);
 msm_dp_bridge_state next{};drm_atomic_commit state{&next.base};
 assert(!msm_dp_get_dsc_config(&dp.msm_dp_display,&state));
 next.dsc.dsc.bits_per_pixel=128;
 assert(msm_dp_get_dsc_config(&dp.msm_dp_display,&state)==&next.dsc.dsc);
 state.bridge=nullptr;
 assert(msm_dp_get_dsc_config(&dp.msm_dp_display,&state)==&panel.dsc.dsc);
 compatible=false;assert(!msm_dp_get_dsc_config(&dp.msm_dp_display,nullptr));compatible=true;
 dp.msm_dp_display.is_edp=true;assert(!msm_dp_get_dsc_config(&dp.msm_dp_display,&state));
 assert(uke_dp_dsc_store(&dev,nullptr,"0\n",2)==2 && !panel.dsc_requested);
}
CPP
"${CXX:-c++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter \
 -fsanitize=undefined -fsanitize-undefined-trap-on-error "$work/test.cpp" -o "$work/test"
"$work/test"
grep -Fx 'static DEVICE_ATTR_RW(uke_dp_dsc);' "$source" >/dev/null
printf '%s\n' 'Actual disconnected DSC policy and per-commit/runtime selection: PASS; host only'
