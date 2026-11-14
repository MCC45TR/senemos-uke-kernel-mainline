#!/usr/bin/bash
# COPR only: actual original/fixed callbacks and meaningful assertion controls.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
source=${1:?Actual prepared fastrpc.c}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
assert_refused() {
    local result
    if "$@" > "$work/refusal.log" 2>&1; then
        printf 'Required original/mutant assertion unexpectedly passed\n' >&2; exit 1
    else result=$?; fi
    [[ $result == 134 ]] || { cat "$work/refusal.log" >&2; exit 1; }
}
for compiler in gcc clang; do
    assert_refused env CC=$compiler bash "$owner/tests/fastrpc-cb-dma-contract.sh" \
        "$owner/tests/fixtures/fastrpc-cb-probe731-original.h"
    for sanitize in 0 1; do
        CC=$compiler SANITIZE=$sanitize bash "$owner/tests/fastrpc-cb-dma-contract.sh" "$source"
        printf 'Actual DMA callback passed: %s/sanitize%s\n' "$compiler" "$sanitize"
    done
done
awk '/^static int fastrpc_cb_probe\(/{p=1}p{print}p&&/^}/{exit}' "$source" > "$work/fixed.h"
for mutation in dma-error stream-id; do
    case $mutation in
      dma-error) sed 's/return rc;/return 0;/' "$work/fixed.h" > "$work/mutant.h";;
      stream-id) sed 's/sess->sid = sid;/sess->sid = sid ^ 1;/' "$work/fixed.h" > "$work/mutant.h";;
    esac
    ! cmp -s "$work/fixed.h" "$work/mutant.h"
    assert_refused env CC=gcc bash "$owner/tests/fastrpc-cb-dma-contract.sh" "$work/mutant.h"
    printf 'Actual DMA callback mutant refused: %s\n' "$mutation"
done
