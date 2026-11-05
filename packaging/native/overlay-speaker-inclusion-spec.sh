#!/usr/bin/env bash
# Pure source edit for the coordinator: retain every original package check.
set -Eeuo pipefail
[[ $# == 1 && -f $1 && ! -L $1 ]]
spec=$(realpath "$1")
grep -Eq '^Name:[[:space:]]+senemos-uke-linux-kernel-mainline-unstable$' "$spec"
[[ $(grep -Fxc '%check' "$spec") == 1 ]]
hook='bash native-profile/packaging/native/check-speaker-inclusion.sh "$PWD" linked %{_uke_out}'
if grep -Fq "$hook" "$spec"; then
 [[ $(grep -Fxc "$hook" "$spec") == 1 ]]
 exit 0
fi
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$spec" "$work/before"
awk -v hook="$hook" '{print} /^%check$/ {print hook}' "$work/before" > "$work/next"
grep -Fvx "$hook" "$work/next" > "$work/without-hook"
cmp "$work/before" "$work/without-hook"
cmp "$spec" "$work/before"
cat "$work/next" > "$spec"
printf '%s\n' 'Linked speaker observer check added to unstable production %check; every old statement retained.'
