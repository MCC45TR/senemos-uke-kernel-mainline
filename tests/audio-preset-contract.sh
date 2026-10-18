#!/usr/bin/env bash
# Host-only synthetic preset audit; no device or OEM payload is needed.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
${CXX:-c++} -std=c++20 -Wall -Wextra -Werror -fsanitize=address,undefined \
    "$root/src/audio/fs19xx-preset-audit.cpp" -o "$work/audit"
"$work/audit" --self-test
