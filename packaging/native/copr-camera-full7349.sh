#!/usr/bin/bash
# Cumulative full9: retain full8, qualified receive layers and read-only EEPROM access.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1");contract=$(realpath "$2")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
jq -e '.schema_version==1 and .full_release==9 and .parent.build==11339909 and .parent.source_files==38 and .native.qualified and .native.release==32 and .physical_acceptance==false and .full_kernel_built==false' "$contract" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/native" "$work/camera-full7349" "$work/keyring" "$work/gnupg"
for role in parent native;do
 id=$(jq -er ".$role.build" "$contract")
 printf 'Full9 source input: %s/build%s\n' "$role" "$id"
 curl -qfsSL --retry 2 --retry-delay 2 --retry-max-time 100 --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$id" > "$work/$role-state.json"
 jq -e --arg url "$(jq -er ".$role.srpm_url" "$contract")" '.state=="succeeded" and .source_package.url==$url' "$work/$role-state.json" >/dev/null
 curl -qfsSL --retry 2 --retry-delay 2 --retry-max-time 900 --max-time 600 --max-filesize 209715200 "$(jq -er ".$role.srpm_url" "$contract")" -o "$work/$role.src.rpm"
 printf '%s  %s\n' "$(jq -er ".$role.srpm_sha256" "$contract")" "$work/$role.src.rpm" | sha256sum -c --strict --quiet -
 rpm2cpio "$work/$role.src.rpm" | cpio -t --quiet > "$work/$role-paths"
 awk -v expected="$(jq -er ".$role.source_files" "$contract")" '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;n++}END{if(bad||n!=expected)exit 1}' "$work/$role-paths"
 member=$(if [[ $role == parent ]];then printf senemos-uke-linux-kernel-mainline-unstable.spec;else printf uke-kernel-migration-check.spec;fi)
 rpm2cpio "$work/$role.src.rpm" | cpio -i --to-stdout --quiet "./$member" > "$work/$role.spec"
 printf '%s  %s\n' "$(jq -er ".$role.spec_sha256" "$contract")" "$work/$role.spec" | sha256sum -c --strict --quiet -
done
bash "$owner/tests/camera-full7349-phases.sh" "$work/parent.spec"
mkdir "$result"
rpm2cpio "$work/parent.src.rpm" | (cd "$result";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$result";find . -type f ! -name senemos-uke-linux-kernel-mainline-unstable.spec ! -name senemos-native-profile-7.3.4.tar.xz ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-inputs.sha256"
rpm2cpio "$work/native.src.rpm" | (cd "$work/native";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner ./uke-camss-lite734.tar.xz ./uke-phy-power734.tar.xz ./uke-csid-irq734.tar.xz ./uke-csid-stream734.tar.xz)
curl -qfsSL --retry 2 --retry-delay 2 --retry-max-time 190 --max-time 90 --max-filesize 2097152 "$(jq -er .native.proof_url "$contract")" -o "$result/camera-native32-proof.rpm"
printf '%s  %s\n' "$(jq -er .native.proof_sha256 "$contract")" "$result/camera-native32-proof.rpm" | sha256sum -c --strict --quiet -
curl -qfsSL --retry 2 --retry-delay 2 --retry-max-time 100 --max-time 45 --max-filesize 65536 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/key.asc"
fingerprint=$(GNUPGHOME="$work/gnupg" gpg --batch --with-colons --show-keys "$work/key.asc" 2>/dev/null | awk -F: '$1=="fpr"{print tolower($10);exit}')
[[ $fingerprint == 2204a661ea630a5303500085538797e72a3e4eca ]]
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --import "$work/key.asc"
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --checksig --verbose "$result/camera-native32-proof.rpm" > "$work/signatures"
[[ $(grep -Eic 'signature.*: OK$' "$work/signatures") == 2 ]]
if grep -Eiq 'NOTFOUND|NOKEY|BAD|NOT OK' "$work/signatures";then exit 1;fi
for name in camss-lite phy-power csid-irq csid-stream;do
 tar -xJf "$work/native/uke-$name"'734.tar.xz' -C "$work/camera-full7349"
 layer=$work/camera-full7349/$name'734'
 (cd "$layer";sha256sum -c --strict --quiet SHA256SUMS)
 expected=$(jq -er --arg name "$name"'734' '.qualified_layers[]|select(.name==$name)|.source_commit' "$contract")
 [[ $(cat "$layer/source-commit") == "$expected" ]]
done
install -m644 "$owner/packaging/native/seal-camera-full7349.sh" "$work/camera-full7349/"
for path in src/camera/front-eeprom734/{apply.sh,pre.sha256,post.sha256,activation.patch} tests/native-front-eeprom734.sh;do
 install -Dm644 "$owner/$path" "$work/camera-full7349/$path"
done
tar -xJf "$result/uke-camera-full7348.tar.xz" -C "$work"
sed 's/uke7[.]3[.]4-8u/uke7.3.4-9u/g;s/two-string7348-to7342/two-string7349-to7342/g' "$work/camera-full7348/verify-parent-source-tuple7348.sh" > "$work/camera-full7349/verify-parent-source-tuple7349.sh"
sed 's/uke7[.]3[.]4-9u/uke7.3.4-8u/g;s/two-string7349-to7342/two-string7348-to7342/g' "$work/camera-full7349/verify-parent-source-tuple7349.sh" | cmp - "$work/camera-full7348/verify-parent-source-tuple7348.sh"
tar -xJf "$result/senemos-native-profile-7.3.4.tar.xz" -C "$work"
tar -xJf "$result/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile;boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
[[ $(cat "$profile/source-commit") == "$(jq -er .parent.source_commit "$contract")" ]]
(cd "$profile";find . -type f ! -name SHA256SUMS ! -name source-commit ! -name source-composition.json ! -path ./manifests/cumulative-release.json ! -path ./src/audio/uke-audio-card.c -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-profile.sha256"
(cd "$boot";find . -type f ! -name lock.json ! -path ./manifests/cumulative-release.json ! -path ./src/audio/uke-audio-card.c -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-boot.sha256"
cp "$profile/manifests/cumulative-release.json" "$work/parent-plan.json"
jq '.full_release=9|.source_check_release=32' "$work/parent-plan.json" > "$work/plan.json"
jq '.full_release=8|.source_check_release=26' "$work/plan.json" | cmp - "$work/parent-plan.json"
curl -qfsSL --retry 2 --retry-delay 2 --retry-max-time 100 --max-time 45 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&packagename=senemos-uke-linux-kernel-mainline-unstable&limit=1000&order=id&order_type=DESC' > "$work/full-history.json"
[[ $(bash "$owner/scripts/kernel-release.sh" next-planned-full "$work/full-history.json" "$work/plan.json") == 9 ]]
before_audio=$(awk '$2=="./src/audio/uke-audio-card.c"||$2=="src/audio/uke-audio-card.c"{print $1}' "$profile/SHA256SUMS")
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/plan.json" "$before_audio"
for tree in "$profile" "$boot";do install -m644 "$work/plan.json" "$tree/manifests/cumulative-release.json";done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
cp "$profile/source-composition.json" "$work/parent-composition.json"
tuple=$(bash "$profile/scripts/kernel-release.sh" json "$work/plan.json")
jq --arg commit "$commit" --argjson tuple "$tuple" --slurpfile q "$contract" '.+{source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,camera_front7349_qualification:{native:$q[0].native,late_front_activation:$q[0].front_activation}}' "$work/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/parent-composition.json" -e '. as $next|all($old[0]|to_entries[];.key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $next[$key]==.value)' "$profile/source-composition.json" >/dev/null
bash "$profile/tests/audio-identity734.sh" "$profile"
(cd "$profile";sha256sum -c --strict --quiet "$work/retained-profile.sha256";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum) > "$work/profile-assets.sha256"
install -m644 "$work/profile-assets.sha256" "$profile/SHA256SUMS"
(cd "$boot";sha256sum -c --strict --quiet "$work/retained-boot.sha256";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets.sha256" > "$work/boot-assets.json"
jq --slurpfile assets "$work/boot-assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/boot-lock.json"
install -m644 "$work/boot-lock.json" "$boot/lock.json"
install -m644 "$work/boot-lock.json" "$result/boot-payload.json"
bash "$owner/packaging/native/fold-camera-full7349.sh" "$result/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/new.spec"
install -m644 "$work/new.spec" "$result/senemos-uke-linux-kernel-mainline-unstable.spec"
install -m644 "$contract" "$result/camera-full7349-qualification.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/senemos-native-profile-7.3.4.tar.xz" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
(cd "$work/camera-full7349";find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/layer.sha256"
mv "$work/layer.sha256" "$work/camera-full7349/SHA256SUMS"
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/uke-camera-full7349.tar.xz" -C "$work" camera-full7349
(cd "$result";sha256sum -c --strict --quiet "$work/retained-inputs.sha256")
