#!/usr/bin/env bash
# Host-only unit generation with a verified original Fedora generator.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
generator=$(realpath -- "${1:?Verified original generator binary required}")
[[ -x $generator ]]
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
for scenario in empty laboratory disabled invalid; do
    fixture=$work/$scenario
    mkdir -p "$fixture/root/proc" "$fixture/root/etc/systemd" "$fixture/units"
    printf 'MemTotal: 7559624 kB\n' > "$fixture/root/proc/meminfo"
    printf '\n' > "$fixture/root/proc/cmdline"
    if [[ $scenario != empty ]]; then
        cp "$root/configs/experiments/zram-generator.conf" \
            "$fixture/root/etc/systemd/zram-generator.conf"
    fi
    if [[ $scenario == disabled ]]; then
        printf 'systemd.zram=0\n' > "$fixture/root/proc/cmdline"
    fi
    if [[ $scenario == invalid ]]; then
        sed -i 's/^zram-size = .*/zram-size = (/' \
            "$fixture/root/etc/systemd/zram-generator.conf"
    fi
    # The upstream test root redirects inputs; an empty PATH blocks external helpers.
    result=0
    ZRAM_GENERATOR_ROOT="$fixture/root" PATH=/nonexistent \
        "$generator" "$fixture/units" > "$fixture/result.log" 2>&1 || result=$?
    cat "$fixture/result.log"
    if [[ $scenario == invalid ]]; then
        [[ $result == 1 ]]
    else
        [[ $result == 0 ]]
    fi
    if [[ $scenario == laboratory ]]; then
        grep -Fx 'What=/dev/zram0' "$fixture/units/dev-zram0.swap"
        grep -Fx 'Priority=100' "$fixture/units/dev-zram0.swap"
        grep -Fx 'Requires=systemd-zram-setup@zram0.service' "$fixture/units/dev-zram0.swap"
        [[ $(readlink "$fixture/units/swap.target.wants/dev-zram0.swap") == ../dev-zram0.swap ]]
        grep -F 'with 1024MB)' "$fixture/result.log"
    else
        [[ -z $(find "$fixture/units" -mindepth 1 -print -quit) ]]
    fi
    printf 'Original generator %s case: PASS\n' "$scenario"
done
