#!/usr/bin/env bash
# COPR only: extract actual production functions; no target sensor request.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
awk '
 /^static const struct iio_mount_matrix \*/ {emit=1;found=1}
 /^static int ssc_suspend/ {done=1;exit}
 emit {print}
 END {if(!found || !done)exit 1}
' "$owner/src/sensors/uke-ssc-iio.c" > "$stage/ssc-mount-actual.h"
for compiler in gcc clang; do
    for mode in plain sanitized; do
        options=(-std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-parameter)
        [[ $mode == plain ]] || options+=(-fsanitize=address,undefined -fno-omit-frame-pointer)
        "$compiler" "${options[@]}" -I"$stage" "$owner/tests/ssc-mount-matrix.c" -o "$stage/check"
        ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$stage/check"
    done
done
# Positive fixtures must detect omitted publication, wrong ownership and absent metadata.
cp "$stage/ssc-mount-actual.h" "$stage/original.h"
for mutation in publication accessor metadata; do
    case $mutation in
        publication) sed 's/s->has_mount_matrix = true;/s->has_mount_matrix = false;/' "$stage/original.h" ;;
        accessor) sed 's/return \&s->mount_matrix;/return NULL;/' "$stage/original.h" ;;
        metadata) sed 's/s->channel\[i\].ext_info = ssc_mount_matrix_info;/(void)ssc_mount_matrix_info;/' "$stage/original.h" ;;
    esac > "$stage/ssc-mount-actual.h"
    ! cmp -s "$stage/original.h" "$stage/ssc-mount-actual.h"
    for compiler in gcc clang; do
        "$compiler" -std=gnu11 -O1 -g -UNDEBUG -Wall -Wextra -Werror \
            -Wno-unused-parameter -Wno-unused-variable -I"$stage" \
            "$owner/tests/ssc-mount-matrix.c" -o "$stage/mutant"
        if (ulimit -c 0; "$stage/mutant") > "$stage/mutant.log" 2>&1; then
            printf 'Mount matrix fixture missed mutation %s/%s\n' "$mutation" "$compiler" >&2
            exit 1
        fi
        grep -q 'Assertion.*failed' "$stage/mutant.log"
    done
done
printf 'Three actual mount callback mutants fail assertions under both compilers\n'
# The matrix is attached to the child declaration before IIO allocation.
[[ $(grep -Fc 'ret = ssc_read_mount_matrix(c, &c->sensor[i], child);' "$owner/src/sensors/uke-ssc-iio.c") == 1 ]]
