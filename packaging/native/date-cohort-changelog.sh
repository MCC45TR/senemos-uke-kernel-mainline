#!/usr/bin/env bash
# Date only this newly generated cohort; preserve retained release history.
set -Eeuo pipefail
[[ $# == 3 ]]
spec=$(realpath -e "${1:?Generated spec}")
revision=${2:?Current revision}
epoch=${3:?Source commit epoch}
[[ $revision =~ ^[1-9][0-9]*$ && $epoch =~ ^[1-9][0-9]{9,}$ ]]
day=$(LC_ALL=C date -u --date="@$epoch" '+%a %b %d %Y')
stage=$(mktemp)
trap 'rm -f -- "$stage"' EXIT
awk -v revision="$revision" -v day="$day" '
 /^%changelog$/ {in_changelog=1}
 in_changelog && /^\* / && $0 ~ (" - 7[.]3[.]1-" revision "$") {
  if (!sub(/^\* [[:alpha:]]{3} [[:alpha:]]{3} [0-9]{1,2} [0-9]{4} /, "* " day " ")) exit 1
  changed++
 }
 {print}
 END {if (!changed) exit 1}
' "$spec" > "$stage"
cat "$stage" > "$spec"
