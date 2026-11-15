#!/usr/bin/bash
# Preserve both historical guards with exact reversible input-only changes.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for tree in "$@";do
 [[ -d $tree && ! -L $tree ]]
 guard=$tree/tests/cdsp-pogo-config-contract.sh
 toolchain=$tree/tests/cdsp-pogo-toolchain-contract.sh
 printf '%s  %s\n' 072f09bb0cc7554b4e2c7c1582c9347c54c776011346c187bfbeeceaa79b955d "$guard" \
  c4bf30ca109ac4bb20046760a89824f094ef7577205d6f018dcaf9c0e6f9f0fe "$toolchain" | sha256sum -c --strict --quiet -
 for kind in guard toolchain;do
  file=$guard;[[ $kind != toolchain ]] || file=$toolchain
  cp "$file" "$work/before"
  awk -v kind="$kind" '
   /^trap .* EXIT$/ {print;print "bash \"$here/project-reference734.sh\" \"$config\" \"$work/upstream-compatible.config\"";inserted++;next}
   /^'\'' "\$config" > "\$work\/(historical-identity|legacy)[.]config"$/ {
    sub(/"\$config"/,"\"$work/upstream-compatible.config\"");input++
   }
   kind=="toolchain" && $0=="bash \"$here/fixtures/cdsp-pogo-config-original.sh\" \"$config\" > \"$work/old-failure.log\" 2>&1" {
    sub(/"\$config"/,"\"$work/upstream-compatible.config\"");failure++
   }
   {print}END{if(inserted!=1||input!=1||(kind=="toolchain"&&failure!=1))exit 1}
  ' "$file" > "$work/after"
  awk '
   $0=="bash \"$here/project-reference734.sh\" \"$config\" \"$work/upstream-compatible.config\"" {next}
   {gsub(/"\$work\/upstream-compatible[.]config"/,"\"$config\"");print}
  ' "$work/after" | cmp - "$work/before"
  bash -n "$work/after"
  install -m644 "$work/after" "$file"
 done
 install -m644 "$owner/tests/project-reference734.sh" "$owner/tests/reference-config734.sh" "$tree/tests/"
 install -m644 "$owner/tests/fixtures/reference733-before734.config" "$tree/tests/fixtures/"
done
printf 'Both historical guards retained by complete inverses; only read-only734 compatibility inputs added. Original7200 digest unchanged.\n'
