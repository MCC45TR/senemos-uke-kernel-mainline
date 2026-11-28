#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
[[ $# == 2 ]]
assets=$(cd -- "$(dirname -- "$0")" && pwd -P)
tree=$(realpath -e -- "$2")
graph=arch/arm64/kernel/uke-cci0-dt.h
patches=("$assets"/000*.patch)
test -f "${patches[0]}"
cd "$tree"

case "$1" in
    prepare)
        [[ ! -e $graph && ! -L $graph ]]
        sha256sum -c --strict "$assets/before.sha256"
        git apply --check --whitespace=error "${patches[@]}"
        git apply --whitespace=error "${patches[@]}"
        sha256sum -c --strict "$assets/after.sha256"
        ;;
    restore)
        sha256sum -c --strict "$assets/after.sha256"
        git apply --reverse --check --whitespace=error "${patches[@]}"
        git apply --reverse --whitespace=error "${patches[@]}"
        [[ ! -e $graph && ! -L $graph ]]
        sha256sum -c --strict "$assets/before.sha256"
        ;;
    *) exit 64 ;;
esac
