#!/usr/bin/env bash
# RPM metadata and installed paths only. Does not compile or access hardware.
set -Eeuo pipefail
spec=${1:?Diagnostic spec}
diagnostics=$(mktemp)
trap 'rm -f "$diagnostics"' EXIT
query() {
 rpmspec --target aarch64 "$@" "$spec" 2> "$diagnostics"
 cat "$diagnostics" >&2
 if grep -q '^error:' "$diagnostics"; then return 1; fi
}
expected=senemos-uke-linux-kernel-mainline-unstable
[[ $(query -q --srpm --qf '%{NAME}') == "$expected" ]]
names=$(query -q --qf '%{NAME}\n')
[[ $names == "$expected"$'\n'"$expected-core"$'\n'"$expected-modules"$'\n'"$expected-dtbs"$'\n'"$expected-boot"$'\n'"$expected-singleboot" ]]
parsed=$(query --parse)
grep -Eq '^Provides: kernel-uname-r\(7[.]3[.]1-[1-9][0-9]*-unstable\)$' <<< "$parsed"
grep -Fq '"automatic_kernel_activation": false' <<< "$parsed"
if grep -E '^Obsoletes:|^Conflicts:|^%(pre|post|preun|postun|pretrans|posttrans|trigger[a-z]*)($|[[:space:]])' <<< "$parsed"; then
 echo 'Diagnostic RPMs must coexist without activation scriptlets' >&2; exit 1
fi
if grep -E '/senemos/default-boot[.]img|uke/singleboot[.]json' <<< "$parsed"; then
 echo 'Diagnostic family must not own the accepted profile selection' >&2; exit 1
fi
if [[ $# == 3 ]]; then
 root=$2 release=$3
 [[ $(readlink "$root/usr/lib/senemos/unstable-default-boot.img") == "kernel-updates/$release/userdata.img" ]]
 [[ ! -e $root/usr/lib/senemos/default-boot.img && ! -e $root/usr/share/senemos/uke/singleboot.json ]]
 jq -e --arg release "$release" '.kernel_release==$release and .automatic_kernel_activation==false' "$root/usr/share/senemos/uke/unstable-singleboot.json" >/dev/null
 [[ -f $root/usr/lib/modules/$release/vmlinuz ]]
fi
printf 'Isolated unstable family, unique Image ABI and explicit trial selection passed\n'
