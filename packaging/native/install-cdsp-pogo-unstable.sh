#!/usr/bin/env bash
# Kernel delivery belongs to the shared cumulative integration queue.
set -Eeuo pipefail
mode=${1:---preview}
[[ $# -le 1 && ( $mode == --preview || $mode == --apply ) ]]
if [[ $mode == --apply ]]; then
    printf '%s\n' 'Standalone CDSP/pogo kernel delivery is retired; use the shared cumulative kernel coordinator.' >&2
    exit 1
fi
printf 'Running kernel: %s\n' "$(uname -r)"
printf 'Selected boot profile: %s\n' "$(readlink /usr/lib/senemos/default-boot.img)"
cat /etc/senemos/kernel-update.conf
printf '%s\n' 'Cumulative baseline: 7.3.1-11003-unstable, COPR11260288.'
printf '%s\n' 'Automatic seamless staging stays enabled. Preserve the local rollback preference; package defaults remain enforced.'
