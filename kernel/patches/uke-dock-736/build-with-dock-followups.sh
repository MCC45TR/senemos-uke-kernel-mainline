#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
tree=$(realpath -e -- "$1")
assets=$(realpath -e -- "$2")
shift 2
[[ $# -gt 0 && $tree != "$assets" ]]
cd "$tree"
header=include/linux/power/uke-typec.h
[[ ! -e $header && ! -L $header ]]
(cd "$assets"; sha256sum -c --strict SHA256SUMS)
sha256sum -c --strict "$assets/base.sha256"
patches=("$assets"/patches/*.patch)
test -f "${patches[0]}"
merged=$(mktemp)
trap 'rm -f -- "$merged"' EXIT
cat "${patches[@]}" > "$merged"
git apply --check --whitespace=error "$merged"
git apply --whitespace=error "$merged"
restore() {
    local status=$?
    trap - EXIT
    git apply --reverse --whitespace=error "$merged" || status=44
    sha256sum -c --strict --quiet "$assets/base.sha256" || status=44
    [[ ! -e $header && ! -L $header ]] || status=44
    if [[ $status != 44 ]]; then
        rm -f -- "$merged"
    else
        printf 'Inspect the incomplete source restoration using %s\n' "$merged" >&2
    fi
    exit "$status"
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sha256sum -c --strict "$assets/postimages.sha256"
"$@"
sha256sum -c --strict --quiet "$assets/postimages.sha256"
