#!/usr/bin/env bash
# Explicit source admission, not hardware approval or a standalone kernel producer.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
profile=$(realpath "${1:?Complete cumulative profile}")
commit=${2:?Exact protected source commit}
[[ $# == 2 && $commit =~ ^[0-9a-f]{40}$ && $(git -C "$owner" rev-parse HEAD) == "$commit" ]]
[[ $(cat "$profile/audio-profile") == microphones ]]
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
hook='bash "$profile/src/audio/prepare-speaker-protected-layer.sh" "$kernel"'
assets=(src/audio/prepare-speaker-protected-layer.sh src/audio/build-protected-topology.sh
 src/audio/sm7675-uke-protected-speaker.dtsi tests/audio-speaker-safety-contract.sh
 tests/audio-speaker-safety.c tests/audio-protected-package-contract.sh
 src/audio/desktop/array-ucm2/Speaker-PCM.conf
 packaging/native/check-speaker-inclusion.sh tests/audio-speaker-observer-code.sh)
layer=$(jq -r '.speaker_protected_layer_commit // ""' "$profile/source-composition.json")
if [[ -n $layer ]]; then
 [[ $layer == "$commit" && $(grep -Fxc "$hook" "$profile/prepare.sh") == 1 ]]
 for asset in "${assets[@]}"; do cmp "$owner/$asset" "$profile/$asset"; done
 jq -e '.speaker_profile_mode=="protected-223" and .speaker_protection_graph_admitted and
 .speaker_gain_ceiling==223 and .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
 exit 0
fi
jq -e '.speaker_controls_layer_commit=="89acf61d73f60f5164104eaffd19c076e6371287" and
 .speaker_legacy_fixture_layer_commit=="f05c32a879b9c56abe3531365f95b85684af4510" and
 .speaker_state_observer_layer_commit=="13fb0ff522531924c0e96f81cef59d7c64b93eb8" and
 .speaker_inclusion_gate_commit=="33a5dc574401b67472e9bea65e5ff7084635f601" and
 .speaker_pre_image_inclusion_required and .speaker_running_state_requires_guard and
 .speaker_gain_ceiling==223 and .speaker_protection_graph_admitted==false and
 .speaker_physical_protection_qualified==false' "$profile/source-composition.json" >/dev/null
! grep -Eq 'xiaomi,fs19xx-protected|foursemi,require-protection' "$profile/src/audio/sm7675-uke-speaker-audio.dtsi"
! grep -Fq "$hook" "$profile/prepare.sh"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
# Authenticate the two replaced checkers against their qualified contribution.
for asset in packaging/native/check-speaker-inclusion.sh tests/audio-speaker-observer-code.sh; do
 git -C "$owner" show "33a5dc574401b67472e9bea65e5ff7084635f601:$asset" | cmp - "$profile/$asset"
done
(cd "$profile"; sha256sum -c --strict --quiet <<'HASH'
5b3a7164e7774f6077cb8f571e0f9108189e86be96bb67581cc75225b8ce33f3  src/audio/desktop/array-ucm2/Speaker-PCM.conf
HASH
)
for asset in "${assets[@]}"; do
 [[ ! -L $profile/$asset ]]
 git -C "$owner" show "$commit:$asset" | cmp - "$owner/$asset"
 case $asset in packaging/native/check-speaker-inclusion.sh|tests/audio-speaker-observer-code.sh|src/audio/desktop/array-ucm2/Speaker-PCM.conf) ;;
 *) [[ ! -e $profile/$asset ]] || cmp "$owner/$asset" "$profile/$asset";; esac
done
cp "$profile/prepare.sh" "$stage/prepare"
cp "$profile/source-composition.json" "$stage/composition"
cp "$profile/src/audio/sm7675-uke-speaker-audio.dtsi" "$stage/speaker-dt"
(cd "$profile"; find . -type f ! -name SHA256SUMS ! -name prepare.sh ! -name source-composition.json \
 ! -path ./src/audio/sm7675-uke-speaker-audio.dtsi ! -path ./packaging/native/check-speaker-inclusion.sh \
 ! -path ./tests/audio-speaker-observer-code.sh ! -path ./src/audio/desktop/array-ucm2/Speaker-PCM.conf -print0 | sort -z | xargs -0 sha256sum) > "$stage/retained"
for asset in "${assets[@]}"; do install -Dm644 "$owner/$asset" "$profile/$asset"; done
printf '\n#include "sm7675-uke-protected-speaker.dtsi"\n' >> "$profile/src/audio/sm7675-uke-speaker-audio.dtsi"
printf '\n%s\n' "$hook" >> "$profile/prepare.sh"
jq --arg commit "$commit" '. + {speaker_protected_layer_commit:$commit,
 speaker_profile_mode:"protected-223",speaker_protection_graph_admitted:true,
 speaker_gain_ceiling:223,speaker_physical_protection_qualified:false}' "$stage/composition" > "$profile/source-composition.json"
(cd "$profile"; sha256sum -c --strict --quiet "$stage/retained")
head -c "$(stat -c %s "$stage/prepare")" "$profile/prepare.sh" | cmp - "$stage/prepare"
head -c "$(stat -c %s "$stage/speaker-dt")" "$profile/src/audio/sm7675-uke-speaker-audio.dtsi" | cmp - "$stage/speaker-dt"
keys='del(.speaker_protected_layer_commit,.speaker_profile_mode,.speaker_protection_graph_admitted)'
cmp <(jq -S "$keys" "$stage/composition") <(jq -S "$keys" "$profile/source-composition.json")
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
printf '%s\n' 'Protected223 source layer appended; all peer bytes retained. Offline private-input check required before target admission.'
