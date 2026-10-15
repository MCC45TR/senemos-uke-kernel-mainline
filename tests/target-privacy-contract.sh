#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d); trap 'rm -rf "$fixture"' EXIT
mkdir "$fixture/bin" "$fixture/payload"
for name in realpath mktemp rm find readlink grep; do ln -s "$(command -v "$name")" "$fixture/bin/$name"; done
expect() {
    local wanted=$1 status=0; shift
    "$@" > "$fixture/output" 2>&1 || status=$?
    [[ $status == "$wanted" ]] || { cat "$fixture/output" >&2; exit 1; }
}
expect 2 env PATH="$fixture/bin" /bin/bash "$root/src/audit/check-target-privacy.sh" "$fixture/payload"
printf '#!/bin/sh\nexit 2\n' > "$fixture/bin/rg"; chmod 755 "$fixture/bin/rg"
expect 2 env PATH="$fixture/bin" /bin/bash "$root/src/audit/check-target-privacy.sh" "$fixture/payload"
rm "$fixture/bin/rg"; ln -s "$(command -v rg)" "$fixture/bin/rg"
expect 0 env PATH="$fixture/bin" /bin/bash "$root/src/audit/check-target-privacy.sh" "$fixture/payload"
printf '/home/private/build/file\n' > "$fixture/payload/test"
expect 1 /bin/bash "$root/src/audit/check-target-privacy.sh" "$fixture/payload"
rm "$fixture/payload/test"
ln -s /home/private/build/file "$fixture/payload/link"
expect 1 /bin/bash "$root/src/audit/check-target-privacy.sh" "$fixture/payload"
echo 'Privacy audit rejects missing tools, scanner errors, private content and symlinks'
