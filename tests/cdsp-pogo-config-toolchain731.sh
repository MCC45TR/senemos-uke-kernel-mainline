#!/usr/bin/env bash
# Preserve the original whole-config guard using an explicit historical model.
set -Eeuo pipefail
config=${1:?Actual normalized kernel configuration}
here=$(cd -- "$(dirname -- "$0")" && pwd)
original=$here/fixtures/cdsp-pogo-config-original.sh
[[ -f $original && ! -L $original ]]
printf '%s  %s\n' fd11aad8209533f50fa5b3a6cf90fb16c223d63bf0bfcfd7304c670e0862a2ef "$original" | sha256sum -c --strict --quiet -
identity=$(grep '^CONFIG_CC_VERSION_TEXT=' "$config")
case $identity in
 'CONFIG_CC_VERSION_TEXT="clang version 23.1.4 (Fedora 23.1.4-1.fc46)"') version=230104;;
 'CONFIG_CC_VERSION_TEXT="clang version 23.1.5 (Fedora 23.1.5-1.fc46)"') version=230105;;
 *) printf 'Unreviewed compiler identity: %s\n' "$identity" >&2;exit 1;;
esac
[[ $(grep -c '^CONFIG_CC_VERSION_TEXT=' "$config") == 1 ]]
for key in CLANG_VERSION AS_VERSION LLD_VERSION;do
 [[ $(grep -c "^CONFIG_$key=" "$config") == 1 ]]
 [[ $(grep -Fxc "CONFIG_$key=$version" "$config") == 1 ]]
done
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
sha256sum "$config" > "$work/actual.sha256"
# Only the four explicitly validated identities are projected to the accepted
#23.1.4 model. Every functional setting stays in the original sealed digest.
# Never rewrite the actual configuration or claim that it used compiler23.1.4.
awk '
 /^CONFIG_CC_VERSION_TEXT=/ {print "CONFIG_CC_VERSION_TEXT=\"clang version 23.1.4 (Fedora 23.1.4-1.fc46)\"";next}
 /^CONFIG_(CLANG_VERSION|AS_VERSION|LLD_VERSION)=/ {sub(/=.*/,"=230104");print;next}
 {print}
' "$config" > "$work/historical-identity.config"
bash "$original" "$work/historical-identity.config"
sha256sum -c --strict --quiet "$work/actual.sha256"
printf 'Historical config guard retained every functional setting; actual compiler identity%s, explicit23.1.4 digest model only.\n' "$version"
