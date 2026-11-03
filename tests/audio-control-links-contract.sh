#!/usr/bin/env bash
# Compile and execute only in a COPR worker. No device access or OEM payload.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/linux"
cat > "$work/linux/types.h" <<'C'
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <endian.h>
typedef uint32_t u32;
typedef uint32_t __le32;
#define cpu_to_le32(x) htole32(x)
#define le32_to_cpu(x) le32toh(x)
C
printf '#include_next <linux/errno.h>\n' > "$work/linux/errno.h"
printf '#include <string.h>\n' > "$work/linux/string.h"
${CC:-cc} -std=gnu11 -Wall -Wextra -Werror -fsanitize=address,undefined \
    -I"$work" -I"$root/src/audio" "$root/tests/audio-control-links.c" -o "$work/check"
"$work/check"
