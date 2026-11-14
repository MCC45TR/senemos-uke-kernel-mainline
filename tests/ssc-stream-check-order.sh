#!/usr/bin/bash
# Text-only regression for the actual spec injector. No compiler/device action.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
inject=$root/packaging/native/inject-ssc-stream-checks.awk
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/parent.spec" <<'SPEC'
%build
bash native-profile/packaging/native/check-dual-light-events733.sh "$PWD" %{_uke_out} prepared
bash native-profile/packaging/native/check-dual-light-events733.sh "$PWD" %{_uke_out} objects
bash native-profile/packaging/native/check-migration-cohort731.sh "$PWD" %{_uke_out} objects
bash native-profile/tests/migration-boot-config-boundary731.sh "$PWD" %{_uke_out}
%install
install retained-documentation
%check
test retained-checks
SPEC
awk -f "$inject" "$work/parent.spec" > "$work/updated.spec"
order() {
 awk '
  $0=="bash native-profile/packaging/native/check-migration-cohort731.sh \"$PWD\" %{_uke_out} objects" {legacy=NR;l++}
  $0=="bash native-profile/tests/migration-boot-config-boundary731.sh \"$PWD\" %{_uke_out}" {boundary=NR;b++}
  $0=="bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} objects" {postimage=NR;n++}
  /^%install$/ {install=NR;i++}
  END{exit !(l==1&&b==1&&n==1&&i==1&&legacy<boundary&&boundary<postimage&&postimage+1==install)}
 ' "$1"
}
order "$work/updated.spec"
awk '!/^bash native-profile\/packaging\/native\/check-ssc-stream-owners733.sh /' \
 "$work/updated.spec" | cmp - "$work/parent.spec"
# Reproduce the source27 placement, retaining exactly the same command text.
awk '
 /check-ssc-stream-owners733.sh .* objects$/ {next}
 {print}
 /check-dual-light-events733.sh .* objects$/ {print "bash native-profile/packaging/native/check-ssc-stream-owners733.sh \"$PWD\" %{_uke_out} objects"}
' "$work/updated.spec" > "$work/original27.spec"
if order "$work/original27.spec"; then exit 1; fi
for mode in missing-prepared duplicate-prepared missing-install duplicate-install; do
 awk -v mode="$mode" '
  /check-dual-light-events733.sh .* prepared$/ {
   if(mode=="missing-prepared")next
   if(mode=="duplicate-prepared")print
  }
  /^%install$/ {
   if(mode=="missing-install")next
   if(mode=="duplicate-install")print
  }
  {print}
 ' "$work/parent.spec" > "$work/invalid.spec"
 if awk -f "$inject" "$work/invalid.spec" > "$work/refused.spec"; then exit 1; fi
done
printf 'SSC source-check order: exact retained spec, final postimage placement, original27 refusal and four malformed-hook refusals passed; text only.\n'
