#!/usr/bin/bash
# Source preparation only. Preserve the actual complete full28 recipe.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/stable734-20261115.json
output=$(realpath -m "$1")
[[ ! -e $output && ! -L $output && -z $(git -C "$owner" status --porcelain) ]]
cert=src/livepatch/uke-livepatch-20261115.pem
git -C "$owner" ls-files --error-unmatch "$cert" >/dev/null
printf '%s  %s\n' "$(jq -er .certificate_pem_sha256 "$owner/manifests/livepatch734-20261115.json")" "$owner/$cert" | sha256sum -c --strict --quiet -
grep -Fxq -- '-----BEGIN CERTIFICATE-----' "$owner/$cert"
! grep -Eq 'BEGIN .*PRIVATE KEY' "$owner/$cert"
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 --max-filesize 314572800 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.3-28.1 ]]
rpm2cpio "$work/parent.src.rpm" | cpio -t --quiet > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
rpm2cpio "$work/parent.src.rpm" | (cd "$output"; cpio -idm --quiet --no-absolute-filenames)
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$parent" | sha256sum -c --strict --quiet -
find "$output" -maxdepth 1 -type f \
 ! -name '*.spec' ! -name 'linux-7.3.3.tar.*' ! -name 'senemos-uke-adaptation-7.3.3.tar.xz' \
 ! -name 'senemos-native-profile-7.3.3.tar.xz' ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json \
 -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
for archive in senemos-native-profile-7.3.3.tar.xz senemos-uke-boot-recipe.tar.xz senemos-uke-adaptation-7.3.3.tar.xz; do
 tar -tJf "$output/$archive" | awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}'
 tar -xJf "$output/$archive" -C "$work"
done
profile=$work/native-profile; boot=$work/boot-recipe; adaptation=$work/senemos-adaptation
(cd "$profile"; sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot"; jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
mkdir "$work/stable734"
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$work/stable734/source-commit"
install -m644 "$manifest" "$work/stable734/manifest.json"
install -m644 "$owner/packaging/native/check-stable734.sh" "$work/stable734/check-stable734.sh"
cp "$profile/source-composition.json" "$work/stable734/parent-composition.json"
sha256sum "$profile/native.config" "$boot/packaging/native/native.config" > "$work/configs.sha256"
jq --slurpfile m "$manifest" '.full_release=$m[0].full_release | .first_full_release=$m[0].first_full_release | .source_check_release=$m[0].source_check_release | .upstream=$m[0].upstream' \
 "$profile/manifests/cumulative-release.json" > "$work/plan.json"
tuple=$(bash "$owner/scripts/kernel-release.sh" json "$work/plan.json")
before_audio=$(awk '$2=="./src/audio/uke-audio-card.c" || $2=="src/audio/uke-audio-card.c"{print $1}' "$profile/SHA256SUMS")
[[ $before_audio =~ ^[a-f0-9]{64}$ ]]
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/plan.json" "$before_audio"
# Change only the admitted helper copies. Inverse comparison retains every
# non-version byte, including hardware gates and existing test assertions.
for pair in "$profile:native_profile" "$boot:boot_recipe"; do
 tree=${pair%:*}; kind=${pair##*:}
 while IFS= read -r path; do
  [[ $path != /* && $path != *..* && -f $tree/$path && ! -L $tree/$path ]]
  sed -e 's/7\.3\.3/7.3.4/g' -e 's/7\\\.3\\\.3/7\\.3\\.4/g' "$tree/$path" > "$work/helper-next"
  sed -e 's/7\.3\.4/7.3.3/g' -e 's/7\\\.3\\\.4/7\\.3\\.3/g' "$work/helper-next" | cmp - "$tree/$path"
  bash -n "$work/helper-next"
  install -m644 "$work/helper-next" "$tree/$path"
 done < <(jq -er --arg kind "$kind" '.version_helper_hashes[$kind]|keys[]' "$tree/manifests/stable733-cumulative-20261107.json")
 install -m644 "$work/plan.json" "$tree/manifests/cumulative-release.json"
 # The signed stable release fixes two missing GPUVM cleanup statements.
 # Reversing precisely that upstream delta recovers the complete old sealed
 # DSI file. Retain the whole-file gate with its reviewed734 preimage.
 seal=$tree/retirement60-parent-files.sha256
 if [[ -f $seal ]]; then
  awk '
   $0=="3e708bfa9ebf15b52a4ecdc2f819da202643b0f9cdf7580de51c62a8b96eadfa  drivers/gpu/drm/msm/dsi/dsi_host.c" {
    $0="868b563940765a3692500fbcbdaa76f8387437ed5f3c5d52a11d873a918c77de  drivers/gpu/drm/msm/dsi/dsi_host.c";n++
   } {print} END{if(n!=1)exit 1}
  ' "$seal" > "$work/seal-next"
  sed 's/^868b563940765a3692500fbcbdaa76f8387437ed5f3c5d52a11d873a918c77de  drivers\/gpu\/drm\/msm\/dsi\/dsi_host.c$/3e708bfa9ebf15b52a4ecdc2f819da202643b0f9cdf7580de51c62a8b96eadfa  drivers\/gpu\/drm\/msm\/dsi\/dsi_host.c/' "$work/seal-next" | cmp - "$seal"
  install -m644 "$work/seal-next" "$seal"
 fi
 for name in audio-unmap-response-contract.sh audio-buffer-submit-contract.sh; do
  case $name in
   audio-unmap-response-contract.sh) expected=8985d8a85c4fe6cdae832d54e00c2d035e1c7c22db540f1bcf563cf1093c40c5;;
   audio-buffer-submit-contract.sh) expected=62c920a634526e0bb0a663dc1a37af8fa82edd039cc87c71cd7407619e257f93;;
  esac
  printf '%s  %s\n' "$expected" "$tree/tests/$name" | sha256sum -c --strict --quiet -
  install -m644 "$owner/tests/$name" "$tree/tests/$name"
 done
done
bash "$owner/packaging/native/prepare-led-overlay734.sh" "$profile" "$boot"
bash "$owner/packaging/native/prepare-livepatch734.sh" "$profile" "$boot"
bash "$owner/packaging/native/prepare-native-vrr734.sh" "$profile" "$boot"
bash "$owner/packaging/native/retarget-pcm-seals734.sh" "$profile" "$boot"
printf '%s\n' "$commit" > "$profile/source-commit"
jq --arg commit "$commit" --argjson tuple "$tuple" '. + {
 source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),
 diagnostic_audio_driver:($tuple.audio_driver|gsub("_";".")),upstream_version:$tuple.version,
 upstream_commit:$tuple.upstream.commit,upstream_sha256:$tuple.upstream.source_sha256,
 rgb_battery_charge_kernel_layer:1,rgb_warning_thresholds_inclusive:true,
 rgb_charge_rearm_percentage_points:2,rgb_healthy_idle_periodic_poll:false,
 rgb_hardware_brightness_limit_unchanged:true,rgb_new_runtime_bridge_packages:0,
 rgb_control_status_reader_qualified:false
}' "$work/stable734/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile parent "$work/stable734/parent-composition.json" -e '
 . as $next | all($parent[0]|to_entries[]; .key as $key |
 (["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver","upstream_version","upstream_commit","upstream_sha256"]|index($key))!=null or $next[$key]==.value)
' "$profile/source-composition.json" >/dev/null
pan=$adaptation/patches/0056-soc-qcom-pmic-altmode-events.patch
bash "$owner/packaging/native/retarget-pmic-altmode734.sh" "$pan" "$work/pan734.patch"
cp "$work/pan734.patch" "$pan"
for number in 0085 0091; do
 name=$(jq -er --arg number "$number" '.compatibility_patches[]|select(.number==$number)|.name' "$manifest")
 before=$(jq -er --arg number "$number" '.compatibility_patches[]|select(.number==$number)|.before_sha256' "$manifest")
 after=$(jq -er --arg number "$number" '.compatibility_patches[]|select(.number==$number)|.after_sha256' "$manifest")
 printf '%s  %s\n' "$before" "$adaptation/patches/$name" | sha256sum -c --strict --quiet -
 printf '%s  %s\n' "$after" "$owner/src/compat/linux734/$name" | sha256sum -c --strict --quiet -
 install -m644 "$owner/src/compat/linux734/$name" "$adaptation/patches/$name"
done
jq --slurpfile m "$manifest" '.version=$m[0].upstream.version | .upstream_commit=$m[0].upstream.commit |
 .source_sha256=$m[0].upstream.source_sha256 | .source_url=$m[0].upstream.source_url |
 .signature_url=$m[0].upstream.signature_url | .source_date_epoch=$m[0].upstream.released_epoch |
 (.patches[]|select(.path|endswith("/0056-soc-qcom-pmic-altmode-events.patch"))).sha256=$m[0].pan_patch_after_sha256 |
 .patches|=map(. as $row|[$m[0].compatibility_patches[]|.name as $name|select($row.path|endswith("/"+$name))] as $matches|
 if ($matches|length)==1 then .sha256=$matches[0].after_sha256 else . end)' \
 < "$adaptation/source-lock.json" > "$work/source-lock.json"
cp "$work/source-lock.json" "$adaptation/source-lock.json"
sha256sum -c --strict --quiet "$work/configs.sha256"
for tree in "$profile" "$boot"; do
 video=$tree/manifests/video-linux73-candidate-20261025.json
 printf '%s  %s\n' b5631a741328f3448a02be52b757842980561bc63431a625d76817c0f25368ed "$tree/tests/iris-sm7675-caps-contract.sh" | sha256sum -c --strict --quiet -
 install -m644 "$owner/tests/iris-sm7675-caps-contract.sh" "$tree/tests/iris-sm7675-caps-contract.sh"
 if [[ $tree == "$boot" ]]; then
  # This archive owns boot helpers and a shared fixture, not the video stack.
  [[ ! -e $tree/patches/video && ! -e $video ]]
  continue
 fi
 while IFS= read -r name; do
  bash "$owner/packaging/native/retarget-iris734.sh" "$tree/patches/video/$name" "$work/iris-next.patch"
  install -m644 "$work/iris-next.patch" "$tree/patches/video/$name"
  hash=$(sha256sum "$work/iris-next.patch"); hash=${hash%% *}
  jq --arg name "$name" --arg hash "$hash" '(.patches[]|select(.path==("patches/video/"+$name))).sha256=$hash' "$video" > "$work/video-next.json"
  cp "$work/video-next.json" "$video"
  unlink "$work/iris-next.patch"
 done <<'PATCHES'
0008-sm7675-firmware-memory-lifetime.patch
0012-sm7675-checked-power-and-oneshot-irq.patch
0013-sm7675-codec-caps-and-q16-rates.patch
PATCHES
done
(cd "$profile"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot"; find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/assets.sha256" > "$work/assets.json"
jq --slurpfile assets "$work/assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/lock.json"
cp "$work/lock.json" "$boot/lock.json"; cp "$work/lock.json" "$output/boot-payload.json"
# Keep historical changelog entries exact. This is source qualification only.
full=$(jq -er .full_release "$manifest")
awk -v full="$full" '/^%changelog$/{exit}{gsub(/7[.]3[.]3/,"7.3.4");if($0=="%global senemos_build_release 28")$0="%global senemos_build_release "full;print}' "$parent" > "$work/candidate.spec"
spec=$output/uke-kernel-migration-check.spec
check=$(jq -er .source_check_release "$manifest")
awk -v check="$check" '/^%description/{exit} /^Name:/{$0="Name: uke-kernel-migration-check"} /^Release:/{$0="Release: "check"%{?dist}"} /^Summary:/{$0="Summary: Full28-preserving Linux7.3.4 source and native object qualification"} /^(Requires|Provides|Recommends|Conflicts|Obsoletes)(\([^)]*\))?:/{next} /^ExclusiveArch:/{print "Source201: uke-stable734.tar.xz"} {print}' "$work/candidate.spec" > "$spec"
printf '\n%%description\nQualify signed Linux7.3.4 against the complete cumulative full28 source and native objects. No full Image, firmware activation or physical acceptance.\n\n' >> "$spec"
awk '/^%prep$/{emit=1}/^%build$/{exit}emit{print}' "$work/candidate.spec" >> "$spec"
printf '\ntar -xJf %%{SOURCE201}\n' >> "$spec"
awk '/^%build$/{emit=1;next}/^bash boot-recipe\/src\/boot\/build-payload[.]sh /{exit}emit{print}' "$work/candidate.spec" >> "$spec"
cat >> "$spec" <<'SPEC'

%build
bash stable734/check-stable734.sh "$PWD" "$PWD/stable734-objects"

%install
install -d %{buildroot}%{_datadir}/%{name}
install -m644 stable734/{manifest.json,source-commit,parent-composition.json} \
 stable734-objects/{source.sha256,native-objects.sha256,config.sha256} \
 %{_topdir}/source-verification.txt %{buildroot}%{_datadir}/%{name}/

%check
test ! -e arch/arm64/boot/Image
test ! -e stable734-objects/arch/arm64/boot/Image
test -s %{buildroot}%{_datadir}/%{name}/native-objects.sha256

%files
%license COPYING
%{_datadir}/%{name}/*

%changelog
* Sun Nov 15 2026 Uke contributors - 7.3.4-7
- Retain cumulative full28 and qualify signed Linux7.3.4 with native objects.
SPEC
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
for pair in senemos-native-profile-7.3.4.tar.xz:native-profile senemos-uke-boot-recipe.tar.xz:boot-recipe senemos-uke-adaptation-7.3.4.tar.xz:senemos-adaptation uke-stable734.tar.xz:stable734; do
 tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/${pair%%:*}" -C "$work" "${pair#*:}"
done
for file in linux-7.3.3.tar.xz linux-7.3.3.tar.sign senemos-native-profile-7.3.3.tar.xz senemos-uke-adaptation-7.3.3.tar.xz "${parent##*/}"; do
 unlink "$output/$file"
done
curl -qfsSL --retry 2 --max-time 600 --max-filesize 209715200 "$(jq -er .upstream.source_url "$manifest")" -o "$output/linux-7.3.4.tar.xz"
curl -qfsSL --retry 2 --max-time 60 --max-filesize 16384 "$(jq -er .upstream.signature_url "$manifest")" -o "$output/linux-7.3.4.tar.sign"
printf '%s  %s\n' "$(jq -er .upstream.source_sha256 "$manifest")" "$output/linux-7.3.4.tar.xz" | sha256sum -c --strict --quiet -
sha256sum -c --strict --quiet "$work/retained.sha256"
printf 'Exact full28 retained; source7.3.4-%s qualification prepared without full revision reservation or hardware operation\n' "$check"
