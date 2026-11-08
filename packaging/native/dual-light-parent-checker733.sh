#!/usr/bin/bash
# Authenticate a narrowly extended checker before exposing its exact parent.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $# == 2 ]]
kernel=$(realpath "${1:?Prepared cumulative kernel}")
name=${2:?Historical checker name}
[[ $name == check-migration-cohort731.sh || $name == check-cumulative-camera731.sh ]]
profile=$kernel/native-profile
history=$profile/history-before-dual-light-delivery
(cd "$history";sha256sum -c --strict --quiet SHA256SUMS)
awk '
 /^dual_light_legacy=\$\(bash / {removed++;next}
 {if(sub(/"\$dual_light_legacy\/drivers\/iio\/common\/uke-ssc\/uke-ssc-iio.c"/,"\"$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c\""))restored++;print}
 END{if(removed!=1||restored!=1)exit 1}
' "$profile/packaging/native/$name" | cmp - "$history/$name"
printf '%s\n' "$history/$name"
