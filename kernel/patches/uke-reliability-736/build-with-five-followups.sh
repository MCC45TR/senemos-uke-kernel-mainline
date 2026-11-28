#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# -ge 3 ]]
tree=$(realpath -e "$1")
assets=$(realpath -e "$2")
shift 2
[[ $tree != "$assets" ]]
(cd "$assets"; sha256sum --strict -c SHA256SUMS)
cd "$tree"
sha256sum --strict -c "$assets/base.sha256"
merged=$(mktemp)
trap 'rm -f -- "$merged"' EXIT
cat "$assets/patches/"0[1-5]-*.patch > "$merged"
git apply --check --whitespace=error "$merged"
git apply --whitespace=error "$merged"
restore() {
    local status=$?
    trap - EXIT
    git apply --reverse --whitespace=error "$merged" || status=44
    sha256sum --strict --quiet -c "$assets/base.sha256" || status=44
    if [[ $status == 44 ]]; then
        printf 'Source reversal needs examination with %s\n' "$merged" >&2
    else
        rm -f -- "$merged"
    fi
    exit "$status"
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sha256sum --strict -c "$assets/postimages.sha256"
"$@"
sha256sum --strict --quiet -c "$assets/postimages.sha256"
