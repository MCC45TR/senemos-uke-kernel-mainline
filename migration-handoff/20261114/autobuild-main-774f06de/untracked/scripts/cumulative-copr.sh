#!/usr/bin/env bash
# Single coordinator pipeline. Credentials never enter arguments or build logs.
set -Eeuo pipefail
set +x
umask 077
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
action=${1:?submit or admit-check}
checkout=$(realpath "${2:?Cumulative source checkout}")
work=$(realpath -m "${3:?Unique evidence directory}")
tuple=$(bash "$checkout/scripts/kernel-release.sh" json "$checkout/manifests/cumulative-release.json")
commit=$(git -C "$checkout" rev-parse HEAD)
[[ $commit =~ ^[a-f0-9]{40}$ && -z $(git -C "$checkout" status --porcelain) ]]
case $action in
 submit)
  mode=${4:?check or full}
  [[ $mode == check || $mode == full ]]
  [[ ! -e $work ]];mkdir -m700 -p "$work"
  revision=$(jq -er .release <<< "$tuple")
  proof=$(jq -er .source_check_release <<< "$tuple")
  extra=()
  project=uke-linux-unstable:custom:kernel-migration-20261105
  if [[ $mode == full ]];then
   [[ $# == 6 && $5 =~ ^[1-9][0-9]*$ && $6 =~ ^[a-f0-9]{64}$ ]]
   proof=$5;extra=("$6");project=uke-linux-unstable
  else [[ $# == 4 ]];fi
  {
   printf '%s\n' '#!/usr/bin/bash' 'set -Eeuo pipefail' 'export LC_ALL=C' "commit=$commit"
   printf '%s\n' 'git init source' 'git -C source remote add origin https://github.com/MCC45TR/senemos-uke-kernel-mainline.git' 'git -C source fetch --depth=1 origin "$commit"' 'git -C source checkout --detach FETCH_HEAD' '[[ $(git -C source rev-parse HEAD) == "$commit" ]]'
   printf '%s\n' 'printf "%%dist .fc%s\n" "$(rpm --eval "%{fedora}")" > "$HOME/.rpmmacros"'
   printf 'bash source/packaging/native/copr-migration-stable733.sh "$PWD/result" %s %s %s' "$revision" "$mode" "$proof"
   if ((${#extra[@]}));then printf ' %s' "${extra[0]}";fi
   printf '\n'
  } > "$work/worker.sh"
  bash -n "$work/worker.sh"
  jq -n --rawfile script "$work/worker.sh" --arg project "$project" '{ownername:"mcc45tr",projectname:"uke-linux-unstable",project_dirname:$project,script:$script,chroot:"fedora-rawhide-aarch64",chroots:["fedora-rawhide-aarch64"],builddeps:"gnupg2 git-core curl jq rpm-build cpio patch tar xz coreutils findutils gawk grep sed diffutils",resultdir:"result",repos:"",enable_net:false}' > "$work/request.json"
  auth=$(mktemp -d);trap 'find "$auth" -depth -delete' EXIT
  [[ ${COPR_LOGIN:-} =~ ^[a-zA-Z0-9._~-]+$ && ${COPR_TOKEN:-} =~ ^[a-zA-Z0-9._~-]+$ ]]
  printf 'user = "%s:%s"\n' "$COPR_LOGIN" "$COPR_TOKEN" > "$auth/curl.conf"
  unset COPR_LOGIN COPR_TOKEN
  # Do not retry a POST with an ambiguous response: its real handle may exist.
  curl -q --config "$auth/curl.conf" -sS --max-time 90 --header 'Content-Type: application/json' --data-binary "@$work/request.json" --output "$work/response.json" --write-out '%{http_code}' https://copr.fedorainfracloud.org/api_3/build/create/custom > "$work/http.status"
  [[ $(cat "$work/http.status") == 2?? ]]
  jq -e '.id|type=="number" and .>0 and .==floor' "$work/response.json" >/dev/null
  jq -c '{id,state}' "$work/response.json"
  ;;
 admit-check)
  id=${4:?Actual COPR handle}
  [[ $# == 4 && $id =~ ^[1-9][0-9]*$ && -s $work/worker.sh && ! -e $work/admission.json ]]
  curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/$id" > "$work/api.json"
  jq -e --arg evr "$(jq -er .source_check_evr <<< "$tuple")" '.state=="succeeded" and .source_package.name=="uke-kernel-migration-check" and .source_package.version==$evr' "$work/api.json" >/dev/null
  curl -q -fLsS --max-time 45 "https://copr.fedorainfracloud.org/api_3/build/source-build-config/$id" | jq -ej .source_dict.script | cmp - "$work/worker.sh"
  url="https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable:custom:kernel-migration-20261105/fedora-rawhide-aarch64/$id-uke-kernel-migration-check"
  evr=$(jq -er .source_check_evr <<< "$tuple")
  curl -q -fLsS --max-time 90 "$url/uke-kernel-migration-check-$evr.fc46.aarch64.rpm" -o "$work/receipt.rpm"
  curl -q -fLsS --max-time 90 "$url/builder-live.log" -o "$work/builder.log"
  curl -q -fLsS --max-time 45 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/pubkey.gpg -o "$work/signing-key.asc"
  mkdir -m700 "$work/keyring"
  gpg --homedir "$work/keyring" --batch --with-colons --show-keys "$work/signing-key.asc" > "$work/key.txt" 2>/dev/null
  [[ $(awk -F: '$1=="fpr"{n++;v=$10}END{if(n!=1)exit 1;print v}' "$work/key.txt") == 2204A661EA630A5303500085538797E72A3E4ECA ]]
  rpmkeys --import "$work/signing-key.asc"
  rpm -Kv "$work/receipt.rpm" > "$work/signatures.txt"
  [[ $(grep -Fc 'key fingerprint: 2204a661ea630a5303500085538797e72a3e4eca: OK' "$work/signatures.txt") == 2 ]]
  ! grep -Eiq 'NOKEY|NOT OK|BAD' "$work/signatures.txt"
  rpm -qp --scripts --triggers --filetriggers "$work/receipt.rpm" > "$work/scripts.txt"
  test ! -s "$work/scripts.txt"
  rpm -qpl "$work/receipt.rpm" > "$work/files.txt"
  ! grep -Ev '^/usr/share/(doc|licenses)/uke-kernel-migration-check(/|$)' "$work/files.txt"
  mkdir -m700 "$work/extracted"
  rpm2cpio "$work/receipt.rpm" | (cd "$work/extracted";cpio -idm --quiet --no-absolute-filenames)
  node "$owner/scripts/admit-cumulative-check.mjs" "$work" "$checkout" "$id" "$commit"
  ;;
 *) exit 2;;
esac
