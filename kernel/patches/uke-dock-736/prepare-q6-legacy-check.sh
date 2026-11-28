#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
assets=$(realpath -e "$1")
original=$assets/q6apm-playback-delivery735.sh
adapted=$assets/q6apm-playback-dfl-check.sh
[[ -f $original && ! -L $original && ! -e $adapted ]]
pattern='cancel_work_sync system_unbound_wq; do'
[[ $(grep -Fc "$pattern" "$original") == 1 ]]
sed -e 's/cancel_work_sync system_unbound_wq; do/cancel_work_sync system_dfl_wq; do/' "$original" > "$adapted"
bash -n "$adapted"
sed -e 's/cancel_work_sync system_dfl_wq; do/cancel_work_sync system_unbound_wq; do/' "$adapted" | cmp "$original" -
