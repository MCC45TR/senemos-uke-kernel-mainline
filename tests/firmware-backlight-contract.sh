#!/usr/bin/env bash
# Host-only contract using the compiled source and upstream backlight helpers.
set -Eeuo pipefail
source_file=${1:?Pass prepared simpledrm.c}
header=${2:?Pass prepared include/linux/backlight.h}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cstddef>
#define container_of(ptr,type,member) reinterpret_cast<type *>(reinterpret_cast<char *>(ptr)-offsetof(type,member))
enum { BACKLIGHT_POWER_ON=0, BACKLIGHT_POWER_OFF=4, BL_CORE_FBBLANK=2 };
struct backlight_device { struct { int power=0, state=0, brightness=102; } props; int actual=102; };
struct drm_device {};
struct drm_crtc { drm_device *dev; };
struct drm_atomic_commit {};
struct simpledrm_device { drm_crtc crtc; backlight_device *backlight; };
int failure=0, errors=0;
int backlight_update_status(backlight_device *bd) {
    if (failure) return failure;
    bd->actual=bd->props.power || (bd->props.state&BL_CORE_FBBLANK) ? 0 : bd->props.brightness;
    return 0;
}
void drm_err(drm_device *, const char *, int error) { assert(error==failure); errors++; }
CPP
    awk '/^static inline int backlight_enable/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$header"
    awk '/^static inline int backlight_disable/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$header"
    awk '/^static void simpledrm_crtc_atomic_(enable|disable)/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$source_file"
    cat <<'CPP'
int main() {
    drm_device dev; backlight_device bl; simpledrm_device display{{&dev},&bl};
    for(int i=0;i<3;i++) {
        simpledrm_crtc_atomic_disable(&display.crtc,nullptr);
        assert(bl.actual==0 && bl.props.power==4 && bl.props.brightness==102);
        simpledrm_crtc_atomic_enable(&display.crtc,nullptr);
        assert(bl.actual==102 && bl.props.power==0 && bl.props.brightness==102);
    }
    display.backlight=nullptr;
    simpledrm_crtc_atomic_disable(&display.crtc,nullptr);
    simpledrm_crtc_atomic_enable(&display.crtc,nullptr);
    assert(errors==0);
    display.backlight=&bl; failure=-5;
    simpledrm_crtc_atomic_disable(&display.crtc,nullptr);
    simpledrm_crtc_atomic_enable(&display.crtc,nullptr);
    assert(errors==2 && bl.props.brightness==102);
}
CPP
} > "$work/check.cpp"
"${CXX:-clang++}" -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter "$work/check.cpp" -o "$work/check"
"$work/check"
grep -F '.atomic_enable = simpledrm_crtc_atomic_enable,' "$source_file" >/dev/null
grep -F '.atomic_disable = simpledrm_crtc_atomic_disable,' "$source_file" >/dev/null
grep -F 'sdev->backlight = devm_of_find_backlight(&pdev->dev);' "$source_file" >/dev/null
printf 'Firmware DRM blank/unblank preserves brightness, absent link is harmless, I/O failures are reported: passed\n'
