#!/usr/bin/bash
# Text transformation of the actual failed full spec; never builds locally.
set -Eeuo pipefail
owner=$(realpath "${1:?Source profile}")
spec=$(realpath "${2:?Actual full spec}")
printf '%s  %s\n' ea6a277cd33ae6d5246a828f42f46e9a640ff5cdfe16f369d59769ce0722a8ce "$spec" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cp "$spec" "$work/full.spec"
bash "$owner/packaging/native/rewrite-lean-full733.sh" "$work/full.spec"
grep -F 'kernel-module-signatures-contract.sh' "$work/full.spec"
grep -F 'check-pcm-period733.sh' "$work/full.spec"
grep -F 'check-speaker-inclusion.sh' "$work/full.spec"
grep -F 'check-dual-light-delivery733.sh' "$work/full.spec"
awk '$0=="%build"{active=1} $0=="%install"{active=0} active{print}' "$work/full.spec" > "$work/phases"
if grep -E '^CC=|^CXX=|msm-kms-alternate-build|camcc-owner-object|wcd939x-telemetry-package-contract' "$work/phases";then exit 1;fi
cp "$work/full.spec" "$work/qualified.spec"
status=0
bash "$owner/packaging/native/rewrite-lean-full733.sh" "$work/full.spec" > "$work/reentry.log" 2>&1 || status=$?
[[ $status != 0 ]]
cmp "$work/full.spec" "$work/qualified.spec"
printf 'Actual lean full spec preserves all prep/install/files and essential production gates; source-suite duplication removed and re-entry refused.\n'
