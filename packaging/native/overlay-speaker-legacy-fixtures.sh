#!/usr/bin/env bash
# Test-only follow-up to the qualified inactive speaker layer. No kernel changes.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Cumulative native profile}")
source_commit=${2:?Exact audio fixture contributor commit}
[[ $# == 2 && $source_commit =~ ^[0-9a-f]{40}$ ]]
[[ $(git -C "$owner" rev-parse HEAD) == "$source_commit" ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
jq -e '.speaker_controls_layer_commit=="89acf61d73f60f5164104eaffd19c076e6371287" and
 .speaker_controls_present_without_graph_admission and .speaker_protected_runtime_abi==1 and
 .speaker_protection_graph_admitted==false and .speaker_gain_ceiling==223 and
 .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
assets=(tests/audio-graph-lifetime-contract.sh tests/audio-readiness-contract.sh
 tests/fixtures/audio-protection-mock.h)
for asset in "${assets[@]}"; do
 git -C "$owner" show "$source_commit:$asset" | cmp - "$owner/$asset"
 [[ ! -L $profile/$asset ]]
done
layer=$(jq -r '.speaker_legacy_fixture_layer_commit // ""' "$profile/source-composition.json")
if [[ -n $layer ]]; then
 [[ $layer == "$source_commit" ]]
 jq -e '.speaker_inherited_audio_fixtures_adapted==true' "$profile/source-composition.json" >/dev/null
 for asset in "${assets[@]}"; do cmp "$owner/$asset" "$profile/$asset"; done
 exit 0
fi
# Authenticate the two exact inherited fixtures before replacing their harnesses.
(cd "$profile"; sha256sum -c --strict --quiet <<'HASHES'
1f948a96e746028ece283b3ba4e8884827f3a48fc39ec0323ffe6e22588b239c  tests/audio-graph-lifetime-contract.sh
8180c110c6fdb5e2b1dc5a30d35dffe346eec2a7e94d4ca6cabc78d118f41e13  tests/audio-readiness-contract.sh
HASHES
)
if [[ -e $profile/tests/fixtures/audio-protection-mock.h ]]; then
 cmp "$owner/tests/fixtures/audio-protection-mock.h" "$profile/tests/fixtures/audio-protection-mock.h"
fi
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
(cd "$profile"; find . -type f ! -name SHA256SUMS ! -name source-composition.json \
 ! -path ./tests/audio-graph-lifetime-contract.sh ! -path ./tests/audio-readiness-contract.sh \
 -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained.sha256"
cp "$profile/source-composition.json" "$stage/composition-before"
for asset in "${assets[@]}"; do
 if [[ -f $profile/$asset ]]; then
  cat "$owner/$asset" > "$profile/$asset"
 else
  install -Dm644 "$owner/$asset" "$profile/$asset"
 fi
done
jq --arg source "$source_commit" '. + {speaker_legacy_fixture_layer_commit:$source,
 speaker_inherited_audio_fixtures_adapted:true}' "$stage/composition-before" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c --strict --quiet "$stage/retained.sha256")
keys='del(.speaker_legacy_fixture_layer_commit,.speaker_inherited_audio_fixtures_adapted)'
cmp <(jq -S "$keys" "$stage/composition-before") <(jq -S "$keys" "$profile/source-composition.json")
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf '%s\n' 'Two inherited audio harnesses and their mock adapted; all production/preparation bytes and gain223 retained.'
