#!/usr/bin/bash
# Retain the entire actual native14 recipe; append the prepared-root layer.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 458d2d6783bafcadb3f4788089f8f7f36494accd80429f671b371755f6c444f7 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_NATIVE_SUPER15_HEADER_BEGIN
Source208: uke-super-root734.tar.xz
# UKE_NATIVE_SUPER15_HEADER_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_NATIVE_SUPER15_BUILD_BEGIN
tar -xJf %{SOURCE208}
(cd super-root734;sha256sum -c --strict --quiet SHA256SUMS)
bash super-root734/tests/native-super-root734.sh "$PWD" "$PWD/stable734-objects"
# UKE_NATIVE_SUPER15_BUILD_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_NATIVE_SUPER15_INSTALL_BEGIN
install -d %{buildroot}%{_datadir}/%{name}/super-root734
install -m644 super-root734-result/{source.sha256,native-objects.sha256,native-results.txt,qualification.json,parent-root-selector.h} super-root734/{source-commit,SHA256SUMS} %{buildroot}%{_datadir}/%{name}/super-root734/
# UKE_NATIVE_SUPER15_INSTALL_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_NATIVE_SUPER15_CHECK_BEGIN
test "$(grep -c '^PASS: super root' super-root734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet super-root734-result/source.sha256
cmp super-root734-result/parent-root-selector.h arch/arm64/kernel/uke-root-selector.h
# UKE_NATIVE_SUPER15_CHECK_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_NATIVE_SUPER15_HISTORY_BEGIN";print "* Mon Nov 16 2026 Uke contributors - 7.3.4-15";print "- Retain the prepared root parser and qualify explicit rescue and super roles with real ARM64 early-boot objects.";print "";print "# UKE_NATIVE_SUPER15_HISTORY_END";next}
 !history{
  if($0=="Release: 14%{?dist}"){$0="Release: 15%{?dist}";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%install"){inject("build");build++;print;inject("install");installs++;next}
  if($0=="%check"){print;inject("check");checks++;next}
 }{print}
 END{if(release!=1||header!=1||build!=1||installs!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_NATIVE_SUPER15_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_NATIVE_SUPER15_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 15%{?dist}"{$0="Release: 14%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-15.fc46 ]]
