#!/usr/bin/env bash
# Host fixtures: retain hardware CPU LUTs; reject changed GPU corner/bus data.
set -Eeuo pipefail
[[ $# == 5 && -x $1 && -s $2 && -s $3 && -s $4 && ! -e $5 ]] || exit 2
binary=$1 input=$2 ufs=$3 usb=$4 out=$5
mkdir -p "$out"
"$binary" "$input" "$ufs" "$usb" "$out/admitted.dtb"
cpu=/soc/qcom,cpufreq-hw
rpmh=/soc/rsc@17a00000/drv@2/clock-controller
gcc=/soc/clock-controller@100000
[[ $(fdtget -t s "$out/admitted.dtb" "$cpu" compatible) == qcom,cpufreq-epss ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$cpu" reg) == '17d91000 1000 17d92000 1000 17d93000 1000' ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$cpu" interrupts) == '0 1e 4 0 1f 4 0 13 4' ]]
[[ $(fdtget -t s "$out/admitted.dtb" "$cpu" clock-names) == 'xo alternate' ]]
[[ $(fdtget -t s "$out/admitted.dtb" "$rpmh" compatible) == qcom,cliffs-rpmh-clk ]]
[[ $(fdtget -t x "$out/admitted.dtb" "$cpu" clocks) == "$(fdtget -t x "$input" "$rpmh" phandle) 0 $(fdtget -t x "$input" "$gcc" phandle) 0" ]]
phandle=$(fdtget -t x "$input" "$cpu" phandle)
index=0
for node in $(fdtget -l "$input" /cpus); do
    case $node in cpu@*) ;; *) continue;; esac
    domain=0; (( index < 3 )) || domain=1; (( index < 7 )) || domain=2
    [[ $(fdtget -t x "$out/admitted.dtb" "/cpus/$node" qcom,freq-domain) == "$phandle $domain" ]]
    ((index+=1))
done
[[ $index == 8 ]]
gpu=/soc/qcom,kgsl-3d0@3d00000
table=$gpu/qcom,gpu-pwrlevels
for node in $(fdtget -l "$input" "$table"); do
    [[ $(fdtget -t u "$input" "$table/$node" qcom,gpu-freq) == 950000000 ]] || continue
    for scenario in corner bus missing duplicate; do
        cp "$input" "$out/$scenario.dtb"
        case $scenario in
            corner) fdtput -t u "$out/$scenario.dtb" "$table/$node" qcom,level 432;;
            bus) fdtput -t u "$out/$scenario.dtb" "$table/$node" qcom,bus-freq 99;;
            missing) fdtput -t u "$out/$scenario.dtb" "$table/$node" qcom,gpu-freq 951000000;;
            duplicate)
                fdtput -c "$out/$scenario.dtb" "$table/duplicate"
                fdtput -t u "$out/$scenario.dtb" "$table/duplicate" qcom,gpu-freq 950000000;;
        esac
        if "$binary" "$out/$scenario.dtb" "$ufs" "$usb" "$out/rejected-$scenario.dtb"; then exit 1; fi
        [[ ! -e "$out/rejected-$scenario.dtb" ]]
    done
    printf 'Three EPSS domains and clocks retained; GPU corner, bus, omission and duplication rejected: passed\n'
    exit 0
done
exit 1
