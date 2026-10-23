#!/usr/bin/env bash
# CLI plans only; no source downloads, containers or compilation.
set -Eeuo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
for jobs in 4 16; do
    for argument in "--j$jobs" "--jobs=$jobs"; do
        result=$(bash "$root/senemos.sh" --build 7.2.12 --distro fedora --dry-run "$argument")
        grep -F "; $jobs jobs;" <<< "$result" >/dev/null
    done
done
result=$(bash "$root/senemos.sh" --build 7.2.12 --distro fedora --dry-run)
grep -F "; $(nproc) jobs;" <<< "$result" >/dev/null
for argument in --j0 --j4bad --jobs=-1 --jobs=01; do
    if bash "$root/senemos.sh" --dry-run "$argument" >/dev/null 2>&1; then
        echo "Invalid jobs accepted: $argument" >&2
        exit 1
    fi
done
if command -v rpmspec >/dev/null; then
    parsed=$(rpmspec --parse --define '_smp_build_ncpus 16' "$root/packaging/senemos-uke-linux-kernel-mainline.spec")
    grep -Fx 'jobs=16' <<< "$parsed" >/dev/null
    if grep -F 'test "$jobs" -le' <<< "$parsed"; then exit 1; fi
fi
echo 'CPU defaults, explicit 4/16 jobs and invalid job refusals passed; no build ran.'
