#!/usr/bin/bash
# Data-only exact whole-file application; keep nested archive Git context out.
set -Eeuo pipefail
[[ $# == 2 ]]
tree=$(realpath "$1")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
contract=$(realpath "$2")
patch=$owner/packaging/native/storage-config-full733.patch
printf '%s  %s\n' "$(jq -er .hooks_patch_sha256 "$contract")" "$patch" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$work/applied" "$work/inverse"
git -C "$work/applied" init -q
git -C "$work/inverse" init -q
while IFS=$'\t' read -r file before after;do
 [[ $file == src/boot/build-payload.sh || $file == packaging/native/prepare-mst-power-delivery733.sh ]]
 [[ -f $tree/$file && ! -L $tree/$file ]]
 printf '%s  %s\n' "$before" "$tree/$file" | sha256sum -c --strict --quiet -
 install -Dm644 "$tree/$file" "$work/applied/$file"
done < <(jq -r '.hooks[]|[.path,.before_sha256,.after_sha256]|@tsv' "$contract")
git -C "$work/applied" apply --check --whitespace=error "$patch"
git -C "$work/applied" apply --whitespace=error "$patch"
while IFS=$'\t' read -r file before after;do
 printf '%s  %s\n' "$after" "$work/applied/$file" | sha256sum -c --strict --quiet -
 bash -n "$work/applied/$file"
 install -Dm644 "$work/applied/$file" "$work/inverse/$file"
done < <(jq -r '.hooks[]|[.path,.before_sha256,.after_sha256]|@tsv' "$contract")
git -C "$work/inverse" apply -R --whitespace=error "$patch"
while IFS= read -r file;do cmp "$tree/$file" "$work/inverse/$file";done < <(jq -r '.hooks[].path' "$contract")
while IFS= read -r file;do install -m644 "$work/applied/$file" "$tree/$file";done < <(jq -r '.hooks[].path' "$contract")
printf 'Storage full hooks:exact full23 preimages,declared postimages and both whole-file inverses passed.\n'
