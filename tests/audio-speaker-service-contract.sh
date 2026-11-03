#!/usr/bin/env bash
# COPR only: native CLI metadata paths, no sound device or unit data.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
cxx=${CXX:-g++}
"$cxx" -std=c++20 -Wall -Wextra -Werror "$owner/src/audio/uke-speaker-runtime.cpp" -lasound -lcrypto -o "$stage/runtime"
"$cxx" -std=c++20 -Wall -Wextra -Werror -shared -fPIC "$owner/tests/audio-speaker-control-mock.cpp" -lasound -o "$stage/control.so"
export LD_PRELOAD=$stage/control.so
"$stage/runtime" --has-control --persist-directory /missing-private-source --acdb /missing-generic-source
for state in {0..5}; do
 UKE_AUDIO_TEST_STATE=$state "$stage/runtime" --status --persist-directory /missing-private-source --acdb /missing-generic-source > "$stage/status.json"
 jq -e --arg state "$(sed -n "$((state+1))p" <<< $'empty\nstaging\nready\nprepared\nrunning\nfault')" \
  '.state==$state and .gain_ceiling==223 and (.physical_protection_qualified|not)' "$stage/status.json" >/dev/null
done
if UKE_AUDIO_TEST_STATE=6 "$stage/runtime" --status > "$stage/error" 2>&1; then exit 1; fi
if UKE_AUDIO_TEST_ABSENT=1 "$stage/runtime" --has-control > "$stage/error" 2>&1; then exit 1; fi
if "$stage/runtime" --status --load > "$stage/error" 2>&1; then exit 1; fi
unset LD_PRELOAD
# Validate the real service with only the executable path relocated for the worker.
sed "s|/usr/bin/uke-speaker-runtime|$stage/runtime|g" \
 "$owner/src/audio/systemd/uke-speaker-provision@.service" > "$stage/uke-speaker-provision@controlC0.service"
mkdir -m700 "$stage/user-run"
XDG_RUNTIME_DIR="$stage/user-run" systemd-analyze --user --generators=no --recursive-errors=no verify --man=no "$stage/uke-speaker-provision@controlC0.service"
printf '%s\n' 'Speaker control-only status, missing-source isolation, gain admission and systemd unit syntax passed; no hardware'
