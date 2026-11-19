#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 2 ]]
mode=$1
overlay=$(realpath "$2")
scratch=$(mktemp -d "$PWD/native-generated/publication-view.XXXXXXXX")
trap 'find "$scratch" -depth -delete' EXIT
files=() arguments=()
while IFS= read -r path; do
    case "$mode:$path" in
        tests:native-profile/src/boot/*|tests:native-profile/tests/mainline-boot-status-contract.sh) ;;
        tests:*|linked:boot-recipe/*|linked:native-profile/src/boot/*|linked:native-profile/tests/mainline-boot-status-contract.sh) continue;;
        linked:*) [[ $path == *.sh ]] || exit 1 ;;
        *) exit 1 ;;
    esac
    [[ $path =~ ^[A-Za-z0-9_./-]+$ && $path != *..* ]]
    install -Dm644 "$path" "$scratch/$path"
    files+=("$path")
    arguments+=("--include=$path")
done < <(sed -n 's|^+++ b/||p' "$overlay")
(( ${#files[@]} > 0 ))
git -C "$scratch" init -q
git -C "$scratch" apply --check "${arguments[@]}" "$overlay"
git -C "$scratch" apply "${arguments[@]}" "$overlay"
if [[ $mode == tests ]]; then
    file=$scratch/native-profile/tests/mainline-boot-status-contract.sh
    sed -i 's/^for release in 7\.3\.0-1-kvm-exit /for release in 7.4.5-senemos-unstable 7.4.5-senemos-kvm 7.3.0-1-kvm-exit /' "$file"
    bash "$file"
else
    checker=$scratch/native-profile/packaging/native/check-migration-cohort731.sh
    sed -i '/^[[:space:]]*bash .*check-speaker-inclusion\.sh.* linked /s/check-speaker-inclusion\.sh/check-speaker-inclusion.sh.publication/' "$checker"
    for path in "${files[@]}"; do
        bash -n "$scratch/$path"
        install -m644 "$scratch/$path" "$path.publication"
    done
fi
