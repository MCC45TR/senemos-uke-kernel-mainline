#!/usr/bin/env bash
# Prepared for the next authorized host session; not run on 25 October.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
bash "$root/src/boot/admit-el2-profile.sh" normal
bash "$root/src/boot/admit-el2-profile.sh" el2-require
if bash "$root/src/boot/admit-el2-profile.sh" el2-exit-experimental; then
    echo 'Unreviewed firmware exit was admitted' >&2; exit 1
else
    [[ $? == 78 ]]
fi
grep -Fx 'CONFIG_ANDROID_BINDER_IPC=y' "$root/packaging/native/native.config"
grep -Fx 'CONFIG_ANDROID_BINDERFS=y' "$root/packaging/native/native.config"
grep -Fx 'CONFIG_ANDROID_BINDER_DEVICES=""' "$root/packaging/native/native.config"
grep -Fq 'x23, x0' "$root/src/boot/uke-el2-entry.S"
grep -Fq 'sigaction(SIGALRM' "$root/src/kvm/probe.cpp"
if grep -Eq '^%(post|posttrans|pre|pretrans)' "$root/packaging/senemos-uke-linux-kernel-mainline.spec"; then
    echo 'Experimental kernel must not activate itself' >&2; exit 1
fi
