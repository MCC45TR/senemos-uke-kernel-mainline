#!/usr/bin/env bash
# Host-side privacy gate for extracted tablet payloads. Never runs target files.
set -euo pipefail
[[ $# == 1 && -d $1 ]] || { echo 'Usage: check-target-privacy.sh EXTRACTED_TARGET_DIRECTORY' >&2; exit 2; }
root=$(realpath -- "$1")
command -v rg >/dev/null 2>&1 || { echo 'Privacy audit requires ripgrep' >&2; exit 2; }
failed=0

matches=$(mktemp)
trap 'rm -f "$matches"' EXIT
status=0
rg -a -l --hidden --no-ignore -e '/home/[^/[:space:]]+/' -e '/Users/[^/[:space:]]+/' -e 'C:[\\]Users[\\]' "$root" > "$matches" || status=$?
((status <= 1)) || { echo 'Privacy audit could not read the complete payload' >&2; exit 2; }
while IFS= read -r path; do
  printf 'Private absolute build path in target payload: %s\n' "${path#"$root/"}" >&2
  failed=1
done < "$matches"

while IFS= read -r -d '' path; do
  link=$(readlink -- "$path")
  if [[ $link =~ ^(/home/[^/]+/|/Users/[^/]+/|[A-Za-z]:\\Users\\) ]]; then
    printf 'Private absolute symlink in target payload: %s\n' "${path#"$root/"}" >&2
    failed=1
  fi
done < <(find "$root" -type l -print0)

if [[ -f $root/prop.default ]]; then
  for expected in 'ro.build.user=uke-builder' 'ro.build.host=uke-build'; do
    if ! grep -Fqx -- "$expected" "$root/prop.default"; then
      printf 'Unsanitized or missing recovery build identity: %s\n' "${expected%%=*}" >&2
      failed=1
    fi
  done
fi

((failed==0)) || exit 1
echo 'Extracted target payload: no recognized private build paths or host identity'
