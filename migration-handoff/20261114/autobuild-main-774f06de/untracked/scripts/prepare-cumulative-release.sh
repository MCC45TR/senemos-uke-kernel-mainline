#!/usr/bin/env bash
# Metadata/signature preparation only. Every native build stays in COPR.
set -Eeuo pipefail
root=$(realpath "${1:?Cumulative source checkout}")
full_history=$(realpath "${2:?Complete full-kernel build history}")
check_history=$(realpath "${3:?Complete source-check build history}")
metadata=$(realpath "${4:?kernel.org releases.json}")
source "$root/scripts/kernel-release.sh"
plan=$root/manifests/cumulative-release.json
current=$(kernel_release_json "$plan")
fields=$(jq -er '
 .latest_stable.version as $version |
 [.releases[]|select(.version==$version and .moniker=="stable" and .iseol==false)] as $r |
 if ($r|length)==1 and ($version|test("^[1-9][0-9]*[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$")) and
    $r[0].source==("https://cdn.kernel.org/pub/linux/kernel/v"+($version|split(".")[0])+".x/linux-"+$version+".tar.xz") and
    $r[0].pgp==("https://cdn.kernel.org/pub/linux/kernel/v"+($version|split(".")[0])+".x/linux-"+$version+".tar.sign") and
    ($r[0].released.timestamp|type=="number" and .>0 and .==floor and .<=now) then
  [$version,$r[0].source,$r[0].pgp,($r[0].released.timestamp|tostring)]|@tsv
 else error("No unique authenticated-source latest stable candidate") end' "$metadata")
IFS=$'\t' read -r version source_url signature_url epoch <<< "$fields"
release=$(kernel_next_release "$full_history" "$version" senemos-uke-linux-kernel-mainline-unstable)
check_release=$(kernel_next_release "$check_history" "$version" uke-kernel-migration-check)
work=$(mktemp -d)
trap 'if [[ -d $work/keyring ]];then gpgconf --homedir "$work/keyring" --kill gpg-agent;fi;find "$work" -depth -delete' EXIT
curl -q -fLsS --retry 2 --max-time 600 "$source_url" -o "$work/source.tar.xz"
curl -q -fLsS --max-time 45 "$signature_url" -o "$work/source.tar.sign"
mkdir -m700 "$work/keyring"
gpg --homedir "$work/keyring" --batch --import "$root/configs/keys/linux-stable.asc" > "$work/key-import" 2>&1
xz -cd "$work/source.tar.xz" | gpg --homedir "$work/keyring" --batch --status-fd 1 --verify "$work/source.tar.sign" - > "$work/signature.status" 2> "$work/signature.log"
primary=$(awk '$1=="[GNUPG:]"&&$2=="VALIDSIG"{n++;key=$NF} END{if(n!=1)exit 1;print key}' "$work/signature.status")
case $primary in 647F28654894E3BD457199BE38DBBDC86092693E|ABAF11C65A2970B130ABE3C479BE3E4300411886) ;; *) exit 1;; esac
tar -xOJf "$work/source.tar.xz" "linux-$version/Makefile" | awk -v expected="$version" '$1=="VERSION"{v=$3}$1=="PATCHLEVEL"{p=$3}$1=="SUBLEVEL"{s=$3}END{if(v"."p"."s!=expected)exit 1}'
tar -xOJf "$work/source.tar.xz" "linux-$version/drivers/nvmem/core.c" > "$work/nvmem-core.c"
# Version automation cannot bypass the actual NVMEM privacy contract.
for function in __nvmem_reg_read __nvmem_reg_write nvmem_bin_attr_get_umode;do
 awk -v name="$function" '$0 ~ "^static (int|umode_t) " name "\\("{copy=1}copy{print}copy&&/^}/{found=1;exit}END{if(!found)exit 1}' "$work/nvmem-core.c" > "$work/$function.h"
done
(cd "$work";printf '%s\n' \
 'b69f844241ff9b858992e618af74c8d1f79c33fa0495464c8cae460625a2acf2  __nvmem_reg_read.h' \
 '296d52ff1cb5ace08ab2a281bd43b5491818a2fcd6d66862a75050e1f5b84b03  __nvmem_reg_write.h' \
 '74b0acfb1aa1f2b41e1dc617b3ae220906a25013c51cedae26dd5ea908ea20a8  nvmem_bin_attr_get_umode.h' | sha256sum -c --strict -)
git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "refs/tags/v$version" "refs/tags/v$version^{}" > "$work/tag"
commit=$(awk '$2~/\^\{\}$/ {n++;v=$1}END{if(n!=1)exit 1;print v}' "$work/tag")
[[ $commit =~ ^[a-f0-9]{40}$ ]]
source_hash=$(sha256sum "$work/source.tar.xz");source_hash=${source_hash%% *}
nvmem_hash=$(sha256sum "$work/nvmem-core.c");nvmem_hash=${nvmem_hash%% *}
jq --arg version "$version" --arg source "$source_url" --arg signature "$signature_url" --arg hash "$source_hash" --arg commit "$commit" --arg primary "$primary" --arg nvmem "$nvmem_hash" --argjson epoch "$epoch" --argjson release "$release" --argjson check "$check_release" '
 .full_release=$release|.source_check_release=$check|
 .upstream={version:$version,commit:$commit,source_sha256:$hash,source_url:$source,signature_url:$signature,primary_signer:$primary,released_epoch:$epoch,source_seals:{"drivers/nvmem/core.c":$nvmem}}
 ' "$plan" > "$work/plan.json"
kernel_release_json "$work/plan.json" > "$work/tuple.json"
install -m644 "$work/plan.json" "$plan"
manifest=$root/manifests/stable733-cumulative-20261107.json
cp "$manifest" "$work/manifest.json"
jq --slurpfile plan "$plan" '.source_check_release=$plan[0].source_check_release|
 .proposed_full_version=$plan[0].upstream.version|.proposed_full_revision=$plan[0].full_release|.full_revision_reserved=false' "$work/manifest.json" > "$manifest"
while IFS= read -r file;do
 [[ $file != /* && $file != *..* && -f $root/$file && ! -L $root/$file ]]
 hash=$(sha256sum "$root/$file");hash=${hash%% *}
 jq --arg path "$file" --arg hash "$hash" '(.source_assets[]|select(.path==$path)|.sha256)=$hash' "$manifest" > "$work/next-manifest.json"
 install -m644 "$work/next-manifest.json" "$manifest"
done < <(jq -er '.source_assets[].path' "$manifest")
bash "$root/tests/kernel-release-contract.sh"
git -C "$root" diff --check
jq -c '{version,release,kernel_release,source_check_evr}' "$work/tuple.json"
