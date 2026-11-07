#!/usr/bin/env bash
# Read-only installed-package audit. Never opens calibration or controls a device.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' |
    jq -Ren --slurpfile policy "$owner/manifests/kernel-package-migration.json" '
      [inputs | split("\t") | select(.[0] | test("^(uke-|xiaomi-uke-|senemos-uke-linux-kernel-)")) |
        {name:.[0],version:.[1]}] | sort_by(.name,.version) |
      map(. as $rpm |
        [$policy[0].groups[] as $group | select($rpm.name|test($group.pattern)) | $group] as $matches |
        $rpm + {groups:[$matches[].id],decisions:[$matches[].decision]}) |
      {schema_version:1,scope:"read-only-installed-package-classification",
       package_removal_authorized:false,packages:.,
       unclassified:[.[]|select(.groups|length==0)|.name],
       ambiguous:[.[]|select(.groups|length>1)|.name]} |
      if (.unclassified|length)==0 and (.ambiguous|length)==0 then .
      else error("Migration policy has unclassified or ambiguous packages: " +
        ((.unclassified+.ambiguous)|unique|join(", "))) end'
