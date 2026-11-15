#!/usr/bin/env bash
# COPR only. Existing proof package family, no full revision or runtime payload.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Source result directory}")
release=${2:?History-derived source proof release}
[[ $release =~ ^[1-9][0-9]*$ && ! -e $output ]]
manifest=$owner/manifests/speaker-enable-readback-20261107.json
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/refuse-published-release.sh" uke-kernel-migration-check "7.3.3-$release"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
tree=$stage/speaker-readback-proof
mkdir -p "$tree" "$output"
while IFS= read -r file;do install -Dm644 "$owner/$file" "$tree/$file";done < <(jq -r '.payload_assets[]' "$manifest")
install -Dm644 "$manifest" "$tree/manifests/${manifest##*/}"
install -m644 "$owner/LICENSE" "$tree/LICENSE"
git -C "$owner" rev-parse HEAD > "$tree/source-commit"
cat > "$tree/SCOPE.txt" <<'SCOPE'
Fixed FS19xx RX/TX enable GET_CFG query draft; in-band only, no DSP writes.
Actual parser and transport with synthetic GPR providers, GCC/Clang + sanitizers.
Not yet linked into or called by a cumulative kernel. No target activation.
Enable responses are not VI samples or proof of proprietary physical limiting.
Full AArch64 kernel-object/lifetime integration and on-device readback remain open.
No gain, calibration, amplifier, routing, firmware, boot or package-provider change.
SCOPE
(cd "$tree";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/speaker-readback-proof.tar.xz" -C "$stage" speaker-readback-proof
sed "s/^%global proof_release 1$/%global proof_release $release/" "$owner/packaging/native/speaker-readback.spec" > "$output/uke-kernel-migration-check.spec"
printf 'Focused speaker readback proof7.3.3-%s; no full kernel or device admission.\n' "$release"
