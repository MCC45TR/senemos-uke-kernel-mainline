#!/usr/bin/env bash
# Read-only observer correction on the inactive cumulative speaker layer.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Cumulative native profile}")
source_commit=${2:?Exact state observer contributor commit}
[[ $# == 2 && $source_commit =~ ^[0-9a-f]{40}$ ]]
[[ $(git -C "$owner" rev-parse HEAD) == "$source_commit" ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.speaker_controls_layer_commit=="89acf61d73f60f5164104eaffd19c076e6371287" and
 .speaker_inherited_audio_fixtures_adapted and .speaker_protection_graph_admitted==false and
 .speaker_gain_ceiling==223 and .speaker_protected_runtime_abi==1 and
 .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
runtime=src/audio/uke-fs19xx-runtime.c
fixture=tests/audio-speaker-state-read-contract.sh
for asset in "$runtime" "$fixture"; do
 git -C "$owner" show "$source_commit:$asset" | cmp - "$owner/$asset"
 [[ ! -L $profile/$asset ]]
done
layer=$(jq -r '.speaker_state_observer_layer_commit // ""' "$profile/source-composition.json")
if [[ -n $layer ]]; then
 [[ $layer == "$source_commit" ]]
 jq -e '.speaker_running_state_requires_guard==true' "$profile/source-composition.json" >/dev/null
 for asset in "$runtime" "$fixture"; do cmp "$owner/$asset" "$profile/$asset"; done
 exit 0
fi
(cd "$profile"; sha256sum -c --strict --quiet <<'HASHES'
c810ec77c028f9a2b679094113b236ed59dd346e739932f9fc73f635d34e8055  src/audio/uke-fs19xx-runtime.c
HASHES
)
if [[ -e $profile/$fixture ]]; then cmp "$owner/$fixture" "$profile/$fixture"; fi
without_observer() {
 awk '/^static int fs19xx_state_get\(/ {skip=1} skip && /^}/ {skip=0;next} !skip {print}' "$1"
}
# No other function, DSP operation, graph callback, threshold or write changes.
cmp <(without_observer "$owner/$runtime") <(without_observer "$profile/$runtime")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
(cd "$profile"; find . -type f ! -name SHA256SUMS ! -name source-composition.json \
 ! -path "./$runtime" -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained.sha256"
cp "$profile/source-composition.json" "$stage/composition-before"
cat "$owner/$runtime" > "$profile/$runtime"
install -Dm644 "$owner/$fixture" "$profile/$fixture"
jq --arg source "$source_commit" '. + {speaker_state_observer_layer_commit:$source,
 speaker_running_state_requires_guard:true}' "$stage/composition-before" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c --strict --quiet "$stage/retained.sha256")
keys='del(.speaker_state_observer_layer_commit,.speaker_running_state_requires_guard)'
cmp <(jq -S "$keys" "$stage/composition-before") <(jq -S "$keys" "$profile/source-composition.json")
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf '%s\n' 'Only read-only speaker status callback changed; graph remains inactive, ABI1/gain223 and every other source retained.'
