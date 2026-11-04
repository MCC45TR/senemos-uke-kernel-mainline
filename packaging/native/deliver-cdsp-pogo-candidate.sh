#!/usr/bin/env bash
# Historical normal-family candidate; superseded by the 4 November policy.
set -Eeuo pipefail
printf '%s\n' 'The 2313 normal-family candidate is historical and is not a deployment target.' >&2
printf '%s\n' 'New CDSP/pogo development uses the unstable package family and an -unstable Image ABI.' >&2
exit 1
