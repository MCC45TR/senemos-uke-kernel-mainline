#!/usr/bin/env bash
# Prepared host-only execution of actual request/callback code with control ON.
# Numerical limits are synthetic; never opens sysfs or a tablet connection.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
UKE_TEST_CONTROL=1 bash "$root/tests/battery-coordinator-contract.sh" "${1:?Pass prepared kernel source}"
