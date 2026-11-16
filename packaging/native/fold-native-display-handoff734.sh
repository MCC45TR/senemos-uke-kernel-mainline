#!/usr/bin/bash
# Append one provider qualification to the complete audited native15 recipe.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 7f14d7ed7c253f0a701c1d2980182c1073fcfb54408033b049d59b3a7a02acf5 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_NATIVE_HANDOFF16_HEADER_BEGIN
Source209: uke-display-handoff734.tar.xz
# UKE_NATIVE_HANDOFF16_HEADER_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_NATIVE_HANDOFF16_BUILD_BEGIN
tar -xJf %{SOURCE209}
(cd display-handoff734;sha256sum -c --strict --quiet SHA256SUMS)
bash display-handoff734/tests/native-display-handoff734.sh "$PWD" "$PWD/stable734-objects"
# UKE_NATIVE_HANDOFF16_BUILD_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_NATIVE_HANDOFF16_INSTALL_BEGIN
install -d %{buildroot}%{_datadir}/%{name}/display-handoff734
install -m644 display-handoff734-result/{source.sha256,native-objects.sha256,native-results.txt,qualification.json,parent-uke-dispcc-votes.c} display-handoff734/{source-commit,SHA256SUMS} %{buildroot}%{_datadir}/%{name}/display-handoff734/
# UKE_NATIVE_HANDOFF16_INSTALL_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_NATIVE_HANDOFF16_CHECK_BEGIN
test "$(grep -c '^PASS: display handoff' display-handoff734-result/native-results.txt)" = 4
sha256sum -c --strict --quiet display-handoff734-result/source.sha256
# UKE_NATIVE_HANDOFF16_CHECK_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_NATIVE_HANDOFF16_HISTORY_BEGIN";print "* Mon Nov 16 2026 Uke contributors - 7.3.4-16";print "- Preserve the firmware MDP clock configuration at registration; retain normal consumer parking and all cumulative checks.";print "";print "# UKE_NATIVE_HANDOFF16_HISTORY_END";next}
 !history{
  if($0=="Release: 15%{?dist}"){$0="Release: 16%{?dist}";release++}
  if($0=="%description"){inject("header");header++}
  if($0=="%install"){inject("build");build++;print;inject("install");installs++;next}
  if($0=="%check"){print;inject("check");checks++;next}
 }{print}
 END{if(release!=1||header!=1||build!=1||installs!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_NATIVE_HANDOFF16_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_NATIVE_HANDOFF16_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 16%{?dist}"{$0="Release: 15%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-16.fc46 ]]
