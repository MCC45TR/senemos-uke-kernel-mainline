#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
set -Eeuo pipefail
export LC_ALL=C
unitdir=usr/lib/systemd/system
units=(uke-root-guard.service uke-initrd-screen.service uke-userdata-grow.service)
listing=$(gzip -cd "$1" | cpio -itv --quiet "${units[@]/#/*\/}")
for unit in "${units[@]}"; do
    awk -v name="$unitdir/$unit" '$1 == "-rw-r--r--" && ($NF == name || $NF == "./" name) { found++ }
        END { if (found != 1) exit 1 }' <<< "$listing"
done
