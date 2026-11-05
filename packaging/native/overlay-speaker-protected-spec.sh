#!/usr/bin/env bash
# Pure unstable spec edit; the coordinator owns full builds and delivery.
set -Eeuo pipefail
[[ $# == 1 && -f $1 && ! -L $1 ]]
spec=$(realpath "$1")
grep -Eq '^Name:[[:space:]]+senemos-uke-linux-kernel-mainline-unstable$' "$spec"
[[ $(grep -Fxc '%check' "$spec") == 1 ]]
[[ $(grep -Fxc 'bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" linked %{_uke_out}' "$spec") == 1 ]]
requirement='Requires: uke-speaker-runtime >= 0.4-2'
hook='bash native-profile/tests/audio-protected-package-contract.sh "%{buildroot}" "%{_uke_out}" "$PWD/native-generated" "%{krel}"'
if grep -Fq "$hook" "$spec"; then
 [[ $(grep -Fxc "$hook" "$spec") == 1 && $(grep -Fxc "$requirement" "$spec") == 1 ]]
 exit 0
fi
! grep -Fq "$requirement" "$spec"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$spec" "$work/before"
awk -v requirement="$requirement" -v hook="$hook" '
 /^%description$/ && !added {print requirement;added=1}
 {print}
 /^%check$/ {print hook}
 END {if (!added) exit 1}' "$work/before" > "$work/next"
grep -Fvx -e "$requirement" -e "$hook" "$work/next" > "$work/retained"
cmp "$work/before" "$work/retained"
cmp "$spec" "$work/before"
cat "$work/next" > "$spec"
printf '%s\n' 'Protected audio runtime dependency and complete package check added; every old spec statement retained.'
