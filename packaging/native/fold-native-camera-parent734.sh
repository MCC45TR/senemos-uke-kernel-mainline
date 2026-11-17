#!/usr/bin/bash
# Keep the complete native24 recipe, including its odd postdivider qualification.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 4f114ab04f20f63cc52769223108de94814d9fe9378b665530f058bcae95acff "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_PARENT25_CHECK_BEGIN
tar -xJf %{SOURCE213}
(cd camera-parent734;sha256sum -c --strict --quiet SHA256SUMS)
bash camera-parent734/tests/native-camera-parent734.sh "$PWD" "$PWD/stable734-objects" "$PWD/camera-parent734" "$PWD/camera-parent734-result"
parent_support=%{buildroot}%{_datadir}/%{name}/camera-parent734
install -d "$parent_support"
install -m644 camera-parent734-result/{source.sha256,native-objects.sha256,results.txt,passive-results.txt,qualification.json} camera-parent734/{source-commit,SHA256SUMS} "$parent_support/"
install -m644 camera-parent734/src/camera/native-parent734/{pre.sha256,post.sha256,parent.patch} "$parent_support/"
sha256sum -c --strict --quiet camera-parent734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CAMERA_PARENT25_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_PARENT25_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-25";print "- Prepare native PLL parents before ROM decoding while retaining firmware ownership and the original guards.";print "";print "# UKE_CAMERA_PARENT25_HISTORY_END";next}
 !history&&$0=="Release: 24%{?dist}"{$0="Release: 25%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_CAMERA_PARENT25_HEADER_BEGIN";print "Source213: uke-camera-parent734.tar.xz";print "# UKE_CAMERA_PARENT25_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_PARENT25_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_PARENT25_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 25%{?dist}"{$0="Release: 24%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-25.fc46 ]]
