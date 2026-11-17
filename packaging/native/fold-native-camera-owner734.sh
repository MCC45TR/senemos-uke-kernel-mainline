#!/usr/bin/bash
# Append one provider qualification to the complete audited native16 recipe.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 6a99c62c69cbfd527ae0208c9d08e5db1f465ab5a72ae093128b514ae6468b9b "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_NATIVE_CAMERA21_HEADER_BEGIN
Source210: uke-camera-owner734.tar.xz
# UKE_NATIVE_CAMERA21_HEADER_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_NATIVE_CAMERA21_BUILD_BEGIN
tar -xJf %{SOURCE210}
(cd camera-owner734;sha256sum -c --strict --quiet SHA256SUMS)
bash camera-owner734/tests/native-camera-owner734.sh "$PWD" "$PWD/stable734-objects"
# UKE_NATIVE_CAMERA21_BUILD_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_NATIVE_CAMERA21_INSTALL_BEGIN
install -d %{buildroot}%{_datadir}/%{name}/camera-owner734
install -m644 camera-owner734-result/{source.sha256,retained.sha256,native-objects.sha256,owner-results.txt,rom-results.txt,startup-results.txt,floor-results.txt,qualification.json,parent-camcc-sm7675.c} camera-owner734/{source-commit,SHA256SUMS} %{buildroot}%{_datadir}/%{name}/camera-owner734/
# UKE_NATIVE_CAMERA21_INSTALL_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_NATIVE_CAMERA21_CHECK_BEGIN
test "$(grep -c '^PASS: camera owner' camera-owner734-result/owner-results.txt)" = 4
test "$(grep -c '^PASS: camera startup snapshot' camera-owner734-result/startup-results.txt)" = 4
test "$(grep -c '^PASS: camera inherited floors' camera-owner734-result/floor-results.txt)" = 4
sha256sum -c --strict --quiet camera-owner734-result/source.sha256 camera-owner734-result/retained.sha256
# UKE_NATIVE_CAMERA21_CHECK_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_NATIVE_CAMERA21_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-21";print "- Separate primary CRM commands from CRMC ROM; qualify synchronized inherited-vote floors and fault retention.";print "";print "# UKE_NATIVE_CAMERA21_HISTORY_END";next}
 !history{
  if($0=="Release: 16%{?dist}"){$0="Release: 21%{?dist}";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%install"){inject("build");build++;print;inject("install");installs++;next}
  if($0=="%check"){print;inject("check");checks++;next}
 }{print}
 END{if(release!=1||header!=1||build!=1||installs!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_NATIVE_CAMERA21_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_NATIVE_CAMERA21_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 21%{?dist}"{$0="Release: 16%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-21.fc46 ]]
