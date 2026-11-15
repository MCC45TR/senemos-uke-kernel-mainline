#!/usr/bin/bash
# Exercise the real producer adapter on temporary text files, without a build.
set -Eeuo pipefail
[[ $# == 1 ]]
owner=$(realpath "${1:?Source profile}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
profile=$work/profile
history=$work/history
mkdir -p "$profile/packaging/native" "$history"
names=(check-migration-cohort731.sh check-cumulative-camera731.sh check-camera-next731.sh)
originals=$owner/packaging/native
if [[ -d $owner/history-before-dual-light-delivery ]]; then
 originals=$owner/history-before-dual-light-delivery
fi
for name in "${names[@]}"; do
 cp "$originals/$name" "$profile/packaging/native/$name"
done
# Run the actual source producer's narrow text adapter, not a rewritten model.
awk '
 $0=="for name in check-migration-cohort731.sh check-cumulative-camera731.sh check-camera-next731.sh; do"{copy=1;found++}
 copy{print}
 copy&&$0=="done"{copy=0}
 END{if(found!=1||copy)exit 1}
' "$owner/packaging/native/copr-dual-light-delivery733.sh" > "$work/adapter.sh"
profile=$profile history=$history bash "$work/adapter.sh"
# Extract the authenticating whole-body inverse from the production helper.
awk '
 /^awk /{copy=1;found++}
 copy{print}
 copy&&/cmp - /{copy=0}
 END{if(found!=1||copy)exit 1}
' "$owner/packaging/native/dual-light-parent-checker733.sh" > "$work/inverse.sh"
for name in "${names[@]}"; do
 profile=$profile history=$history name=$name bash "$work/inverse.sh"
 cmp "$originals/$name" "$history/$name"
 cp "$profile/packaging/native/$name" "$work/qualified"
 printf '\n# independent alteration outside the SSC adapter\n' >> "$profile/packaging/native/$name"
 status=0
 profile=$profile history=$history name=$name bash "$work/inverse.sh" > "$work/refusal.log" 2>&1 || status=$?
 [[ $status != 0 ]]
 cp "$work/qualified" "$profile/packaging/native/$name"
 printf 'Actual dual-light checker adapter inverse and unrelated alteration refusal passed:%s.\n' "$name"
done
printf 'All three production SSC comparison adapters preserve every other checker byte; text-only validation.\n'
