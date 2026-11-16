#!/usr/bin/bash
# Late source layer only; retain the full legacy codec through an exact inverse.
set -Eeuo pipefail
[[ $# == 1 ]]
boot=$(realpath "$1")
here=$(cd -- "$(dirname -- "$0")" && pwd)
file=$boot/src/boot/boot-image.cpp
printf '%s  %s\n' deab992b29201d6973f6f8f1a694c356e7c7ba5f2d6b5f4d31ddca35f085358b "$file" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/src/boot"
cp "$file" "$work/parent.cpp"
cp "$file" "$work/src/boot/boot-image.cpp"
# A boot recipe may be nested inside the kernel's Git tree. Own the patch root
# explicitly so Git cannot silently skip paths relative to an outer repository.
git -C "$work" init -q
git -C "$work" apply --check "$here/boot-profiles.patch"
git -C "$work" apply "$here/boot-profiles.patch"
printf '%s  %s\n' a37fefd6f64c510ef142940046f561cbc554f2d0350e091e0663f7fa42975b9f "$work/src/boot/boot-image.cpp" | sha256sum -c --strict --quiet -
cp "$work/src/boot/boot-image.cpp" "$work/new.cpp"
git -C "$work" apply --reverse "$here/boot-profiles.patch"
cmp "$work/parent.cpp" "$work/src/boot/boot-image.cpp"
install -m644 "$work/new.cpp" "$file"
jq '.source_assets |= map(if .path=="src/boot/boot-image.cpp" then .sha256="a37fefd6f64c510ef142940046f561cbc554f2d0350e091e0663f7fa42975b9f" else . end)' "$boot/lock.json" > "$work/lock.json"
mv "$work/lock.json" "$boot/lock.json"
echo 'Boot codec whole inverse passed; new profiles require one exact aligned kernel capability.'
