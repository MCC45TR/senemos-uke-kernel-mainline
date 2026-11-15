#!/usr/bin/bash
# Add an exact inverse input for the retained MST linked source ledger only.
set -Eeuo pipefail
[[ $# == 2 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for tree in "$@";do
 file=$tree/packaging/native/prepare-mst-power-delivery733.sh
 printf '%s  %s\n' b6b539a1db00c15ecba5f89760b041d70a44a72596979eefbb680c794e9cdbd9 "$file" | sha256sum -c --strict --quiet -
 cp "$file" "$work/before"
 awk '
  $0=="(cd \"$kernel\";sha256sum -c --strict --quiet \"$work/applied.sha256\")" {
   print "bash \"$profile/tests/vrr734-historical-source-check.sh\" \"$kernel\" \"$work/applied.sha256\"";n++;next
  }
  {print}END{if(n!=1)exit 1}
 ' "$file" > "$work/after"
 awk '
  $0=="bash \"$profile/tests/vrr734-historical-source-check.sh\" \"$kernel\" \"$work/applied.sha256\"" {
   print "(cd \"$kernel\";sha256sum -c --strict --quiet \"$work/applied.sha256\")";next
  }{print}
 ' "$work/after" | cmp - "$work/before"
 bash -n "$work/after"
 install -m644 "$work/after" "$file"
 install -m644 "$owner/tests/vrr734-historical-source-check.sh" "$owner/tests/vrr734-historical-source.sh" "$tree/tests/"
done
printf 'Original MST linked checker preserved by a whole inverse; actual new VRR source and original five-file history are both checked.\n'
