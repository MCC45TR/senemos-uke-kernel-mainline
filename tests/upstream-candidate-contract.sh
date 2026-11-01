#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
source "$root/scripts/prepare-upstream-candidate.sh"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cat > "$work/release.json" <<'JSON'
{"latest_stable":{"version":"7.3"},"releases":[{"moniker":"mainline","version":"7.3","source":"https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.tar.xz","pgp":"https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.tar.sign","released":{"timestamp":1792365298}}]}
JSON
[[ $(release_fields "$work/release.json" | cut -f1) == 7.3 ]]
jq '.releases[0].source="https://example.invalid/linux-7.3.tar.xz"' "$work/release.json" > "$work/foreign.json"
if release_fields "$work/foreign.json" 2>/dev/null; then exit 1; fi
jq '.releases += [.releases[0]]' "$work/release.json" > "$work/duplicate.json"
if release_fields "$work/duplicate.json" 2>/dev/null; then exit 1; fi
jq '.latest_stable.version="7.3/../../foreign"' "$work/release.json" > "$work/path.json"
if release_fields "$work/path.json" 2>/dev/null; then exit 1; fi
cat > "$work/contract" <<'TEXT'
7.2.11-16-kvm 7\.2\.11-16 7[.]2[.]11-16
7.2.11 7\.2\.11 7[.]2[.]11
TEXT
replace_version "$work/contract" 7.2.11 7.3.0 16 1
cat > "$work/expected" <<'TEXT'
7.3.0-1-kvm 7\.3\.0-1 7[.]3[.]0-1
7.3.0 7\.3\.0 7[.]3[.]0
TEXT
cmp "$work/contract" "$work/expected"
echo 'Exact upstream URLs, duplicate/path refusal and plain/regex version identities passed'
