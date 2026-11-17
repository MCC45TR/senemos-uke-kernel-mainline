#!/usr/bin/bash
# Preserve the complete native22 recipe; add error-report qualification last.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 0cf5fbeba9551ff0ccc1baea4ff8944ece8e95cee3135bb56e185b43ce9c91e3 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_ROM23_CHECK_BEGIN
tar -xJf %{SOURCE211}
(cd camera-rom-report734;sha256sum -c --strict --quiet SHA256SUMS)
bash camera-rom-report734/tests/native-camera-rom-report734.sh "$PWD" "$PWD/stable734-objects" "$PWD/camera-rom-report734" "$PWD/camera-rom-report734-result"
report_support=%{buildroot}%{_datadir}/%{name}/camera-rom-report734
install -d "$report_support"
install -m644 camera-rom-report734-result/{source.sha256,native-objects.sha256,reporter-results.txt,composition-results.txt,qualification.json} camera-rom-report734/{source-commit,SHA256SUMS} "$report_support/"
install -m644 camera-rom-report734/src/camera/rom-report734/{pre.sha256,post.sha256,report.patch,rom-report.h} "$report_support/"
sha256sum -c --strict --quiet camera-rom-report734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CAMERA_ROM23_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_ROM23_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-23";print "- Qualify bounded cached diagnostics for the native CRM ROM refusal; preserve all admission checks.";print "";print "# UKE_CAMERA_ROM23_HISTORY_END";next}
 !history && $0=="Release: 22%{?dist}"{$0="Release: 23%{?dist}";releases++}
 !history && $0=="%description"{print "# UKE_CAMERA_ROM23_HEADER_BEGIN";print "Source211: uke-camera-rom-report734.tar.xz";print "# UKE_CAMERA_ROM23_HEADER_END";headers++}
 !history && $0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_ROM23_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_ROM23_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 23%{?dist}"{$0="Release: 22%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-23.fc46 ]]
