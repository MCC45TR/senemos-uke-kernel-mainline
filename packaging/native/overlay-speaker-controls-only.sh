#!/usr/bin/env bash
# Pure source overlay. No revision reservation, kernel build or target operation.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Cumulative native profile}")
source_commit=${2:?Exact audio contributor commit}
[[ $# == 2 && $source_commit =~ ^[0-9a-f]{40}$ ]]
[[ $(cat "$profile/audio-profile") == microphones ]]
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
hook='bash "$profile/src/audio/prepare-speaker-controls-only.sh" "$kernel"'
layer=$(jq -r '.speaker_controls_layer_commit // ""' "$profile/source-composition.json")
if [[ -n $layer ]]; then
 [[ $layer == "$source_commit" && $(grep -Fxc "$hook" "$profile/prepare.sh") == 1 ]]
 while read -r asset; do cmp "$owner/$asset" "$profile/$asset"; done < "$owner/packaging/native/audio-controls-only-assets.list"
 jq -e '.speaker_protection_graph_admitted==false and .speaker_gain_ceiling==223 and
  .speaker_controls_present_without_graph_admission and .speaker_protected_runtime_abi==1 and
  .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
 exit 0
fi
! grep -Fq "$hook" "$profile/prepare.sh"
! grep -Eq 'xiaomi,fs19xx-protected|foursemi,require-protection' "$profile/src/audio/sm7675-uke-speaker-audio.dtsi"
jq -e '(.speaker_protection_graph_admitted // false)==false and
 (.speaker_gain_ceiling // 223)==223 and (.speaker_physical_protection_qualified // false)==false' "$profile/source-composition.json" >/dev/null
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
(cd "$profile";find . -type f ! -name SHA256SUMS ! -name prepare.sh ! -name source-composition.json -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained.sha256"
cp "$profile/prepare.sh" "$stage/prepare-before"
cp "$profile/source-composition.json" "$stage/composition-before"
# Never replace an existing cumulative asset with different bytes.
while read -r asset; do
 if [[ -e $profile/$asset ]]; then cmp "$owner/$asset" "$profile/$asset"; fi
done < "$owner/packaging/native/audio-controls-only-assets.list"
while read -r asset; do install -Dm644 "$owner/$asset" "$profile/$asset"; done < "$owner/packaging/native/audio-controls-only-assets.list"
printf '\n%s\n' "$hook" >> "$profile/prepare.sh"
jq --arg source "$source_commit" '. + {speaker_controls_layer_commit:$source,
 speaker_controls_present_without_graph_admission:true,speaker_protected_runtime_abi:1,
 speaker_protection_graph_admitted:false,speaker_gain_ceiling:223,
 speaker_physical_protection_qualified:false}' "$stage/composition-before" > "$profile/source-composition.json"
(cd "$profile";sha256sum -c --strict --quiet "$stage/retained.sha256")
head -c "$(stat -c %s "$stage/prepare-before")" "$profile/prepare.sh" | cmp - "$stage/prepare-before"
keys='del(.speaker_controls_layer_commit,.speaker_controls_present_without_graph_admission,
 .speaker_protected_runtime_abi,.speaker_protection_graph_admitted,.speaker_gain_ceiling,.speaker_physical_protection_qualified)'
cmp <(jq -S "$keys" "$stage/composition-before") <(jq -S "$keys" "$profile/source-composition.json")
(cd "$profile";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf '%s\n' 'Controls-only audio layer added; all pre-existing source/config/DT/topology/UCM/firmware bytes retained.'
