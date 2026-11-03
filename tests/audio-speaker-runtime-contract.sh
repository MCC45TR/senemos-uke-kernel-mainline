#!/usr/bin/env bash
# COPR only: no compilation or execution of project binaries on the tablet.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
"${CXX:-clang++}" -std=c++20 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I"$owner/src/audio" "$owner/tests/audio-speaker-runtime.cpp" -lcrypto -o "$stage/test"
"$stage/test" "$@"
"${CXX:-clang++}" -std=c++20 -Wall -Wextra -Werror \
    "$owner/src/audio/uke-speaker-runtime.cpp" -lasound -lcrypto -o "$stage/runtime"
