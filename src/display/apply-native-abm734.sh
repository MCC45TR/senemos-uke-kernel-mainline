#!/usr/bin/bash
# Late layer after retained7342 source checks; never a live device operation.
set -Eeuo pipefail
[[ $# == 1 ]]
kernel=$(realpath "$1")
here=$(cd -- "$(dirname -- "$0")" && pwd)
[[ $kernel != / && -f $kernel/Makefile ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
(cd "$kernel";sha256sum -c --strict --quiet "$here/abm734-parent.sha256")
while read -r hash path;do
 [[ $hash =~ ^[a-f0-9]{64}$ && $path =~ ^(drivers|include)/[A-Za-z0-9_./-]+$ && $path != *..* ]]
 [[ -f $kernel/$path && ! -L $kernel/$path ]]
 (cd "$kernel";cp --parents "$path" "$work/")
done < "$here/abm734-parent.sha256"
[[ $(wc -l < "$here/abm734-parent.sha256") == 6 ]]
git -C "$kernel" apply --check "$here/0077-o82-live-abm734.patch"
git -C "$kernel" apply "$here/0077-o82-live-abm734.patch"
(cd "$kernel";sha256sum -c --strict --quiet "$here/abm734-post.sha256")
mkdir "$work/inverse"
while read -r hash path;do (cd "$kernel";cp --parents "$path" "$work/inverse/");done < "$here/abm734-parent.sha256"
git -C "$work/inverse" apply --reverse "$here/0077-o82-live-abm734.patch"
while read -r hash path;do cmp "$work/$path" "$work/inverse/$path";done < "$here/abm734-parent.sha256"
printf 'ABM source layer preserves all six7342 inputs through a complete inverse; native compilation and device acceptance remain separate.\n'
