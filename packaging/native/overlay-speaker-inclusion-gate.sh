#!/usr/bin/env bash
# Pure source overlay: enforce the observer before Image, retain all peer layers.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Cumulative native profile}")
source_commit=${2:?Exact inclusion-check source commit}
[[ $# == 2 && $source_commit =~ ^[0-9a-f]{40}$ && $(git -C "$owner" rev-parse HEAD) == "$source_commit" ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.speaker_state_observer_layer_commit=="13fb0ff522531924c0e96f81cef59d7c64b93eb8" and
 .speaker_running_state_requires_guard and .speaker_protection_graph_admitted==false and
 .speaker_gain_ceiling==223 and .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
assets=(manifests/speaker-required-inputs-20261105.json packaging/native/check-speaker-inclusion.sh tests/audio-speaker-observer-code.sh)
hook='bash "$profile/packaging/native/check-speaker-inclusion.sh" "$kernel" prepared'
layer=$(jq -r '.speaker_inclusion_gate_commit // ""' "$profile/source-composition.json")
for asset in "${assets[@]}"; do
 git -C "$owner" show "$source_commit:$asset" | cmp - "$owner/$asset"
 [[ ! -L $profile/$asset ]]
 if [[ -e $profile/$asset ]]; then cmp "$owner/$asset" "$profile/$asset"; fi
done
if [[ -n $layer ]]; then
 [[ $layer == "$source_commit" && $(grep -Fxc "$hook" "$profile/prepare.sh") == 1 ]]
 jq -e '.speaker_pre_image_inclusion_required==true' "$profile/source-composition.json" >/dev/null
 exit 0
fi
! grep -Fq "$hook" "$profile/prepare.sh"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
(cd "$profile"; find . -type f ! -name SHA256SUMS ! -name prepare.sh ! -name source-composition.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained"
cp "$profile/prepare.sh" "$stage/prepare-before"
cp "$profile/source-composition.json" "$stage/composition-before"
for asset in "${assets[@]}"; do install -Dm644 "$owner/$asset" "$profile/$asset"; done
printf '\n%s\n' "$hook" >> "$profile/prepare.sh"
jq --arg commit "$source_commit" '. + {speaker_inclusion_gate_commit:$commit,
 speaker_pre_image_inclusion_required:true}' "$stage/composition-before" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c --strict --quiet "$stage/retained")
head -c "$(stat -c %s "$stage/prepare-before")" "$profile/prepare.sh" | cmp - "$stage/prepare-before"
keys='del(.speaker_inclusion_gate_commit,.speaker_pre_image_inclusion_required)'
cmp <(jq -S "$keys" "$stage/composition-before") <(jq -S "$keys" "$profile/source-composition.json")
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf '%s\n' 'Speaker observer inclusion gate appended before Image; all prior source and peer hooks retained.'
