#!/usr/bin/bash
# COPR only; add a machine control without changing codec/protection code.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
profile=$kernel/native-profile
for name in uke-speaker-display.h uke-speaker-display-control.h; do
 install -m644 "$profile/src/audio/$name" "$kernel/sound/soc/qcom/$name"
done
git -C "$kernel" apply --check "$profile/src/audio/0029-uke-speaker-display-control.patch"
git -C "$kernel" apply "$profile/src/audio/0029-uke-speaker-display-control.patch"
printf 'Native speaker display control added; codec position/gain/protection and DT endpoint geometry retained.\n'
