#!/usr/bin/env bash
# Host-only: extract the actual sysfb update loop and check destination bounds.
set -Eeuo pipefail
[[ $# == 1 && -s $1 ]]
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/clip.cpp" <<'CPP'
#include <algorithm>
#include <cassert>
#include <cstddef>
#include <cstdio>
struct drm_rect { int x1,y1,x2,y2; };
static void drm_rect_translate(drm_rect *r,int x,int y) { r->x1+=x;r->x2+=x;r->y1+=y;r->y2+=y; }
static bool drm_rect_intersect(drm_rect *r,const drm_rect *other) {
    r->x1=std::max(r->x1,other->x1);r->y1=std::max(r->y1,other->y1);
    r->x2=std::min(r->x2,other->x2);r->y2=std::min(r->y2,other->y2);
    return r->x1<r->x2 && r->y1<r->y2;
}
struct iosys_map { size_t offset; };
static void iosys_map_incr(iosys_map *dst,size_t offset) {dst->offset+=offset;}
static size_t drm_fb_clip_offset(unsigned pitch,void *,const drm_rect *r) {return r->y1*pitch+r->x1*4;}
struct plane_state_type { drm_rect src,dst; };
struct sysfb_type { iosys_map fb_addr; };
struct shadow_type { void *data; int fmtcnv_state; };
static unsigned copies;
static drm_rect copied;
static size_t destination;
static void blit_to_crtc(iosys_map *dst,unsigned *pitch,void *,void *,drm_rect *clip,int *) {
    assert(clip->x2>clip->x1 && clip->y2>clip->y1);
    const auto last=dst->offset+size_t(clip->y2-clip->y1-1)*(*pitch)+size_t(clip->x2-clip->x1)*4;
    assert(last<=size_t(3200)*2136*4);
    assert(size_t(clip->x2-clip->x1)*4<=*pitch);
    copies++;copied=*clip;destination=dst->offset;
}
static void update(plane_state_type *plane_state,drm_rect damage) {
    sysfb_type backing{{0}};auto *sysfb=&backing;
    shadow_type shadow{};auto *shadow_plane_state=&shadow;
    unsigned dst_pitch=12800;void *dst_format=nullptr,*fb=nullptr;
CPP
perl -0777 -ne '/drm_atomic_for_each_plane_damage\(&iter, &damage\) \{(.*?)^\t\}/ms or die "Missing actual damage loop\n"; print "$1\n";' "$1" | sed 's/\bcontinue;/return;/' >> "$fixture/clip.cpp"
cat >> "$fixture/clip.cpp" <<'CPP'
}
int main() {
    plane_state_type plane{{0,0,3200<<16,2136<<16},{0,0,3200,2136}};
    update(&plane,{0,0,3201,2137});
    assert(copies==1 && copied.x2==3200 && copied.y2==2136 && destination==0);
    copies=0;update(&plane,{3199,2135,3201,2137});
    assert(copies==1 && copied.x1==3199 && copied.y1==2135 && copied.x2==3200 && copied.y2==2136);
    copies=0;update(&plane,{3200,0,3201,1});assert(!copies);
    copies=0;update(&plane,{0,2136,1,2137});assert(!copies);
    plane.src={100<<16,20<<16,3300<<16,2156<<16};
    copies=0;update(&plane,{100,20,3301,2157});
    assert(copies==1 && copied.x1==100 && copied.y1==20 && copied.x2==3300 && copied.y2==2156 && destination==0);
    copies=0;update(&plane,{3299,2155,3301,2157});
    assert(copies==1 && copied.x1==3299 && copied.y1==2155 && copied.x2==3300 && copied.y2==2156);
    puts("Actual sysfb loop: oversized damage, last pixel, outside clips and panning bounds passed");
}
CPP
"${CXX:-c++}" -std=c++17 -O2 -Wall -Wextra -Werror "$fixture/clip.cpp" -o "$fixture/check"
"$fixture/check"
