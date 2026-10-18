#!/usr/bin/env bash
# Host-only: compile the actual SMEM-backed sysfs getters with bounded fixtures.
set -Eeuo pipefail
source_file=${1:?Pass the prepared socinfo.c}
project=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
sed -n '/^static ssize_t hw_platform_show/,/^static struct attribute \*uke_sensor_attrs/p' "$source_file" | sed '$d' > "$work/profile-functions.h"
${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -Werror -Wno-unused-parameter -I "$work" "$project/tests/socinfo-sensor-profile.cpp" -o "$work/profile"
"$work/profile"
printf '%s\n' 'SMEM profile getters preserve actual numeric fields and reject unknown labels'
