#!/usr/bin/bash
# Verify every native13 source byte, with only the declared audio tuple inverse.
set -Eeuo pipefail
[[ $# == 2 ]]
kernel=$(realpath "$1");proof=$(realpath "$2")
[[ -f $kernel/Makefile && ! -L $proof ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
card=sound/soc/qcom/uke-audio-card.c
awk -v card="$card" '
 $1!~/^[a-f0-9]+$/||length($1)!=64||$2!~/^[A-Za-z0-9_./-]+$/||index($2,"..")||seen[$2]++{bad=1}
 $2==card{audio++;next}
 {print}
 END{if(bad||audio!=1)exit 1}
' "$proof" > "$work/unchanged.sha256"
(cd "$kernel";sha256sum -c --strict --quiet "$work/unchanged.sha256")
awk '
 {needle="\"uke7.3.4-3u\"";old="\"uke7.3.4-2u\"";while(pos=index($0,needle)){$0=substr($0,1,pos-1)old substr($0,pos+length(needle));n++}print}
 END{if(n!=2)exit 1}
' "$kernel/$card" > "$work/parent-card.c"
expected=$(awk -v card="$card" '$2==card{print $1}' "$proof")
printf '%s  %s\n' "$expected" "$work/parent-card.c" | sha256sum -c --strict --quiet -
printf 'Complete native13 source proof passed, including the whole audio card after the exact two-string7343-to7342 inverse.\n'
