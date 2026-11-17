#!/usr/bin/bash
# Keep the complete native23 recipe, including its cached error reporter.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 090dfdab0158c478a048ba600a49dbde64f2311fb6b5722267ae0faf86bddd05 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_ODD24_CHECK_BEGIN
tar -xJf %{SOURCE212}
(cd camera-odd734;sha256sum -c --strict --quiet SHA256SUMS)
bash camera-odd734/tests/native-camera-odd734.sh "$PWD" "$PWD/stable734-objects" "$PWD/camera-odd734" "$PWD/camera-odd734-result"
odd_support=%{buildroot}%{_datadir}/%{name}/camera-odd734
install -d "$odd_support"
install -m644 camera-odd734-result/{source.sha256,native-objects.sha256,results.txt,qualification.json} camera-odd734/{source-commit,SHA256SUMS} "$odd_support/"
install -m644 camera-odd734-result/model/actual-postdiv-tables.h "$odd_support/catalog-tables.h"
install -m644 camera-odd734/src/camera/rom-odd734/{pre.sha256,post.sha256,odd.patch} "$odd_support/"
sha256sum -c --strict --quiet camera-odd734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CAMERA_ODD24_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_ODD24_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-24";print "- Qualify the original catalog odd postdivider field without changing firmware ownership or voltage limits.";print "";print "# UKE_CAMERA_ODD24_HISTORY_END";next}
 !history&&$0=="Release: 23%{?dist}"{$0="Release: 24%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_CAMERA_ODD24_HEADER_BEGIN";print "Source212: uke-camera-odd734.tar.xz";print "# UKE_CAMERA_ODD24_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_ODD24_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_ODD24_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 24%{?dist}"{$0="Release: 23%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-24.fc46 ]]
