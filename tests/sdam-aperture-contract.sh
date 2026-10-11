#!/usr/bin/env bash
# Host-only check of the actual SDAM size setup and register bounds predicate.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cstddef>
struct sdam_chip { unsigned int size; struct { unsigned int size; } sdam_config; };
CPP
    awk '/^#define SDAM_MEM_START|^#define SDAM_PBS_TRIG_SET|^#define SDAM_PBS_TRIG_CLR/ {print}
         /^static bool sdam_is_valid\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$kernel/drivers/nvmem/qcom-spmi-sdam.c"
    printf 'void setup(sdam_chip *sdam, unsigned int val) {\n'
    awk '/sdam->size = val \* 32;|sdam->sdam_config.size =/ {print}' "$kernel/drivers/nvmem/qcom-spmi-sdam.c"
    cat <<'CPP'
}
bool nvmem_read_allowed(sdam_chip *sdam, unsigned int offset, size_t count) {
    return offset < sdam->sdam_config.size && count <= sdam->sdam_config.size - offset &&
           sdam_is_valid(sdam, offset, count);
}
int main() {
    for (unsigned int blocks : {1U, 4U, 6U}) {
        sdam_chip chip{};
        setup(&chip, blocks);
        const unsigned int end = 0x40 + blocks * 32;
        assert(chip.sdam_config.size == end);
        assert(!nvmem_read_allowed(&chip, 0x3f, 1));
        assert(!nvmem_read_allowed(&chip, 0x40, 0));
        assert(nvmem_read_allowed(&chip, 0x40, 1));
        assert(nvmem_read_allowed(&chip, end - 1, 1));
        assert(!nvmem_read_allowed(&chip, end - 1, 2));
        assert(!nvmem_read_allowed(&chip, end, 1));
        if (blocks >= 4) assert(nvmem_read_allowed(&chip, 0xaf, 1));
    }
}
CPP
} > "$work/check.cpp"
g++ -std=c++20 -O2 -Wall -Wextra -Werror -include initializer_list "$work/check.cpp" -o "$work/check"
"$work/check"
echo 'SDAM actual size setup: full data aperture admitted; header, zero length and end overrun rejected'
