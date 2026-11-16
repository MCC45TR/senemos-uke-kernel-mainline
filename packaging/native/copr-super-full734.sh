#!/usr/bin/bash
# COPR source assembly only; the separate allocator owns full4 submission.
set -Eeuo pipefail
[[ $# == 2 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1");contract=$(realpath "$2")
[[ ! -e $result && ! -L $result && -z $(git -C "$owner" status --porcelain) ]]
jq -e '.schema_version==1 and .full_release==4 and .native.qualified==true and .native.release==15 and .initrd.qualified==true and .initrd.release==6 and .parent.build==11333235 and .parent.source_commit=="44be649381405be367cfbc47af92447545b11a1d" and .full_kernel_built==false and .physical_acceptance==false' "$contract" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/keyring" "$work/gnupg" "$work/native" "$work/initrd" "$work/full4"
for role in parent native initrd;do
 id=$(jq -er ".$role.build" "$contract")
 curl -qfsSL --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$id" > "$work/$role-state.json"
 jq -e --arg url "$(jq -er ".$role.srpm_url" "$contract")" '.state=="succeeded" and .source_package.url==$url' "$work/$role-state.json" >/dev/null
 curl -qfsSL --max-time 600 --max-filesize 209715200 "$(jq -er ".$role.srpm_url" "$contract")" -o "$work/$role.src.rpm"
 printf '%s  %s\n' "$(jq -er ".$role.srpm_sha256" "$contract")" "$work/$role.src.rpm" | sha256sum -c --strict --quiet -
 rpm2cpio "$work/$role.src.rpm" | cpio -t --quiet > "$work/$role-paths"
 awk -v expected="$(jq -er ".$role.source_files" "$contract")" '{name=$0;sub(/^\.\//,"",name);if(name!~/^[A-Za-z0-9_.+-]+$/||seen[name]++)bad=1;count++}END{if(bad||count!=expected)exit 1}' "$work/$role-paths"
done
mkdir "$result"
rpm2cpio "$work/parent.src.rpm" | (cd "$result";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
(cd "$result";find . -type f ! -name senemos-uke-linux-kernel-mainline-unstable.spec ! -name senemos-native-profile-7.3.4.tar.xz ! -name senemos-uke-boot-recipe.tar.xz ! -name boot-payload.json -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-inputs.sha256"
rpm2cpio "$work/native.src.rpm" | (cd "$work/native";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner ./uke-super-root734.tar.xz)
rpm2cpio "$work/initrd.src.rpm" | (cd "$work/initrd";cpio -idm --quiet --no-absolute-filenames --no-preserve-owner ./uke-super-early-source.tar.xz)
for role in native initrd;do
 curl -qfsSL --max-time 90 --max-filesize 1048576 "$(jq -er ".$role.proof_url" "$contract")" -o "$result/super734-$role-proof.rpm"
 printf '%s  %s\n' "$(jq -er ".$role.proof_sha256" "$contract")" "$result/super734-$role-proof.rpm" | sha256sum -c --strict --quiet -
done
curl -qfsSL --max-time 45 --max-filesize 65536 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/key.asc"
fingerprint=$(GNUPGHOME="$work/gnupg" gpg --batch --with-colons --show-keys "$work/key.asc" 2>/dev/null | awk -F: '$1=="fpr"{print tolower($10);exit}')
[[ $fingerprint == 2204a661ea630a5303500085538797e72a3e4eca ]]
rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --import "$work/key.asc"
for role in native initrd;do
 rpmkeys --define "_dbpath $work" --define '_keyring fs' --define "_keyringpath $work/keyring" --checksig --verbose "$result/super734-$role-proof.rpm" > "$work/signatures"
 [[ $(grep -Eic 'signature.*: OK$' "$work/signatures") == 2 ]]
 ! grep -Eiq 'NOTFOUND|NOKEY|BAD|NOT OK' "$work/signatures"
done
tar -xJf "$work/native/uke-super-root734.tar.xz" -C "$work"
tar -xJf "$work/initrd/uke-super-early-source.tar.xz" -C "$work"
(cd "$work/super-root734";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$work/early-super";sha256sum -c --strict --quiet SHA256SUMS)
[[ $(cat "$work/super-root734/source-commit") == "$(jq -er .native.source_commit "$contract")" ]]
mv "$work/super-root734" "$work/full4/root15"
mv "$work/early-super" "$work/full4/early"
install -Dm644 "$owner/packaging/native/verify-parent-source-tuple7344.sh" "$work/full4/packaging/native/verify-parent-source-tuple7344.sh"
tar -xJf "$result/senemos-native-profile-7.3.4.tar.xz" -C "$work"
tar -xJf "$result/senemos-uke-boot-recipe.tar.xz" -C "$work"
profile=$work/native-profile;boot=$work/boot-recipe
(cd "$profile";sha256sum -c --strict --quiet SHA256SUMS)
(cd "$boot";jq -r '.source_assets[]|.sha256+"  "+.path' lock.json | sha256sum -c --strict --quiet -)
[[ $(cat "$profile/source-commit") == "$(jq -er .parent.source_commit "$contract")" ]]
(cd "$profile";find . -type f ! -name SHA256SUMS ! -name source-commit ! -name source-composition.json ! -path ./manifests/cumulative-release.json ! -path ./src/audio/uke-audio-card.c -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-profile.sha256"
(cd "$boot";find . -type f ! -name lock.json ! -path ./manifests/cumulative-release.json ! -path ./src/audio/uke-audio-card.c -print0 | sort -z | xargs -0 sha256sum) > "$work/retained-boot.sha256"
cp "$profile/manifests/cumulative-release.json" "$work/parent-plan.json"
jq '.full_release=4|.source_check_release=15' "$work/parent-plan.json" > "$work/plan.json"
jq '.full_release=3|.source_check_release=14' "$work/plan.json" | cmp - "$work/parent-plan.json"
curl -qfsSL --max-time 45 'https://copr.fedorainfracloud.org/api_3/build/list?ownername=mcc45tr&projectname=uke-linux-unstable&packagename=senemos-uke-linux-kernel-mainline-unstable&limit=1000&order=id&order_type=DESC' > "$work/full-history.json"
[[ $(bash "$owner/scripts/kernel-release.sh" next-planned-full "$work/full-history.json" "$work/plan.json") == 4 ]]
before_audio=$(awk '$2=="./src/audio/uke-audio-card.c"||$2=="src/audio/uke-audio-card.c"{print $1}' "$profile/SHA256SUMS")
bash "$owner/packaging/native/retarget-audio-tuple733.sh" "$profile" "$boot" "$work/plan.json" "$before_audio"
for tree in "$profile" "$boot";do install -m644 "$work/plan.json" "$tree/manifests/cumulative-release.json";done
commit=$(git -C "$owner" rev-parse HEAD)
printf '%s\n' "$commit" > "$profile/source-commit"
cp "$profile/source-composition.json" "$work/parent-composition.json"
tuple=$(bash "$profile/scripts/kernel-release.sh" json "$work/plan.json")
jq --arg commit "$commit" --argjson tuple "$tuple" --slurpfile q "$contract" '.+{source_commit:$commit,kernel_release:$tuple.kernel_release,rpm_revision:($tuple.release|tostring),diagnostic_audio_driver:$tuple.audio_driver,super_root_layer:1,super_root_native_qualification:$q[0].native,super_initrd_native_qualification:$q[0].initrd,super_root_physical_acceptance:false}' "$work/parent-composition.json" > "$profile/source-composition.json"
jq --slurpfile old "$work/parent-composition.json" -e '. as $next|all($old[0]|to_entries[];.key as $key|(["source_commit","kernel_release","rpm_revision","diagnostic_audio_driver"]|index($key))!=null or $next[$key]==.value)' "$profile/source-composition.json" >/dev/null
bash "$profile/tests/audio-identity734.sh" "$profile"
(cd "$profile";sha256sum -c --strict --quiet "$work/retained-profile.sha256";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$boot";sha256sum -c --strict --quiet "$work/retained-boot.sha256";find . -type f ! -name lock.json -print0 | sort -z | xargs -0 sha256sum) > "$work/boot-assets.sha256"
jq -Rn '[inputs|capture("^(?<sha256>[a-f0-9]{64})  [.]?/?(?<path>.*)$")]|map({path,sha256})' < "$work/boot-assets.sha256" > "$work/boot-assets.json"
jq --slurpfile assets "$work/boot-assets.json" '.source_assets=$assets[0]' "$boot/lock.json" > "$work/boot-lock.json"
install -m644 "$work/boot-lock.json" "$boot/lock.json"
install -m644 "$work/boot-lock.json" "$result/boot-payload.json"
bash "$owner/packaging/native/fold-super-full734.sh" "$result/senemos-uke-linux-kernel-mainline-unstable.spec" "$work/new.spec"
install -m644 "$work/new.spec" "$result/senemos-uke-linux-kernel-mainline-unstable.spec"
install -m644 "$contract" "$result/super734-full-qualification.json"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/senemos-native-profile-7.3.4.tar.xz" -C "$work" native-profile
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/senemos-uke-boot-recipe.tar.xz" -C "$work" boot-recipe
(cd "$work/full4";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$result/uke-super-full734.tar.xz" -C "$work" full4
(cd "$result";sha256sum -c --strict --quiet "$work/retained-inputs.sha256")
printf 'Cumulative full7344 assembled from actual7343, signed native15 and signed early-initrd6; source preparation only, hardware acceptance remains open.\n'
