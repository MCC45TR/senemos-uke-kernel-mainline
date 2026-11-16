#!/usr/bin/bash
# Host test launcher only. Keep original system-scope analysis and private /run.
set -Eeuo pipefail
[[ $# -gt 0 && ! -e /etc/senemos/kernel-update.conf ]]
exec unshare --user --map-root-user --mount --fork /usr/bin/bash -ceu '
 mount --make-rprivate /
 mount -t tmpfs -o size=8M,nosuid,nodev,mode=0755 uke-unit-private-run /run
 exec setpriv --bounding-set=-all --inh-caps=-all --ambient-caps=-all --no-new-privs \
  /usr/bin/systemd-analyze "$@"
' private-system-scope "$@"
