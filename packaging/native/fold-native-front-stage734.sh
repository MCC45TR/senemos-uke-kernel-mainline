#!/usr/bin/bash
# Retain the complete source32 recipe and qualify the front gate's entry phase.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 83649dac95cab14b7a0e2cf4ba96022667ba8aaab3d321905209981f0ba0761b "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_FRONT_STAGE33_CHECK_BEGIN
tar -xJf %{SOURCE218}
(cd front-stage734;sha256sum -c --strict --quiet SHA256SUMS)
bash front-stage734/tests/native-front-stage734.sh "$PWD" "$PWD/stable734-objects" "$PWD/front-stage734" "$PWD/front-stage734-result"
front_support=%{buildroot}%{_datadir}/%{name}/front-stage734
install -d "$front_support"
install -m644 front-stage734-result/{source.sha256,native-objects.sha256,results.txt,disabled-results.txt,qualification.json} front-stage734/{source-commit,SHA256SUMS} "$front_support/"
install -m644 front-stage734/src/camera/front-stage734/{pre.sha256,post.sha256,late-stage.patch} "$front_support/"
sha256sum -c --strict --quiet front-stage734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_FRONT_STAGE33_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_FRONT_STAGE33_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-33";print "- Check the read-only front gate after native MC/GEM tags and packed-tree expansion.";print "";print "# UKE_FRONT_STAGE33_HISTORY_END";next}
 !history&&$0=="Release: 32%{?dist}"{$0="Release: 33%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_FRONT_STAGE33_HEADER_BEGIN";print "Source218: uke-front-stage734.tar.xz";print "# UKE_FRONT_STAGE33_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_FRONT_STAGE33_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_FRONT_STAGE33_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 33%{?dist}"{$0="Release: 32%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-33.fc46 ]]
