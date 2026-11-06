#!/usr/bin/env bash
# COPR only: actual olddefconfig output, original failure and refusal controls.
set -Eeuo pipefail
config=${1:?Actual normalized reference}
here=$(cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
identity=$(grep '^CONFIG_CC_VERSION_TEXT=' "$config")
[[ $identity == 'CONFIG_CC_VERSION_TEXT="clang version 23.1.5 (Fedora 23.1.5-1.fc46)"' ]]
sha256sum "$config" > "$work/original.sha256"
if ! bash "$here/cdsp-pogo-config-contract.sh" "$config";then
 printf 'Historical guard refused; raw input versus actual normalization follows.\n' >&2
 diff -u "$here/../configs/governor-before-nfc-cdsp.config" "$config" | head -n 240 >&2 || :
 exit 1
fi
awk '
 /^CONFIG_CC_VERSION_TEXT=/ {print "CONFIG_CC_VERSION_TEXT=\"clang version 23.1.4 (Fedora 23.1.4-1.fc46)\"";next}
 /^CONFIG_(CLANG_VERSION|AS_VERSION|LLD_VERSION)=/ {sub(/=.*/,"=230104");print;next}
 {print}
' "$config" > "$work/legacy.config"
bash "$here/fixtures/cdsp-pogo-config-original.sh" "$work/legacy.config"
# Unmodified guard must reproduce check18 on the real23.1.5 output.
set +e
bash "$here/fixtures/cdsp-pogo-config-original.sh" "$config" > "$work/old-failure.log" 2>&1
result=$?
set -e
[[ $result == 1 ]]
for mutant in functional mixed missing duplicate unreviewed;do
 case $mutant in
 functional)
  awk '/^CONFIG_NR_CPUS=/{if($0=="CONFIG_NR_CPUS=999")exit 1;$0="CONFIG_NR_CPUS=999";changed++}{print}END{if(changed!=1)exit 1}' "$config" > "$work/mutant.config";;
 mixed) sed 's/^CONFIG_AS_VERSION=230105$/CONFIG_AS_VERSION=230104/' "$config" > "$work/mutant.config";;
 missing) sed '/^CONFIG_LLD_VERSION=/d' "$config" > "$work/mutant.config";;
 duplicate) cat "$config" > "$work/mutant.config";printf 'CONFIG_CLANG_VERSION=230105\n' >> "$work/mutant.config";;
 unreviewed) sed 's/^CONFIG_CLANG_VERSION=230105$/CONFIG_CLANG_VERSION=230106/' "$config" > "$work/mutant.config";;
 esac
 ! cmp -s "$config" "$work/mutant.config"
 set +e
 bash "$here/cdsp-pogo-config-contract.sh" "$work/mutant.config" > "$work/$mutant.log" 2>&1
 result=$?
 set -e
 [[ $result == 1 ]]
 printf 'Historical config refusal control passed: %s.\n' "$mutant"
done
sha256sum -c --strict --quiet "$work/original.sha256"
printf 'Actual23.1.5 olddefconfig differs only by four reviewed compiler identities from the sealed23.1.4 model; original failure and five refusal controls pass.\n'
