#!/usr/bin/bash
# Preserve the complete successful native31 recipe through a whole-file inverse.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' b46df1d9102bc237b028c66b03ccf0a41021c01555dd7f27f0d7d564102225c4 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CSID_STREAM32_CHECK_BEGIN
tar -xJf %{SOURCE217}
(cd csid-stream734;sha256sum -c --strict --quiet SHA256SUMS)
bash csid-stream734/tests/native-csid-stream734.sh "$PWD" "$PWD/stable734-objects" "$PWD/csid-stream734" "$PWD/csid-stream734-result"
csid_support=%{buildroot}%{_datadir}/%{name}/csid-stream734
install -d "$csid_support"
install -m644 csid-stream734-result/{source.sha256,native-objects.sha256,results.txt,qualification.json} csid-stream734/{source-commit,SHA256SUMS} "$csid_support/"
install -m644 csid-stream734/src/camera/csid-stream734/{pre.sha256,post.sha256,stream.patch} "$csid_support/"
install -m644 csid-stream734-result/model/after/donor-stream.h "$csid_support/donor-stream.h"
sha256sum -c --strict --quiet csid-stream734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CSID_STREAM32_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CSID_STREAM32_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-32";print "- Qualify every CSID start and stop with fixed media links and the native gen3 dispatch.";print "";print "# UKE_CSID_STREAM32_HISTORY_END";next}
 !history&&$0=="Release: 31%{?dist}"{$0="Release: 32%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_CSID_STREAM32_HEADER_BEGIN";print "Source217: uke-csid-stream734.tar.xz";print "# UKE_CSID_STREAM32_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CSID_STREAM32_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CSID_STREAM32_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 32%{?dist}"{$0="Release: 31%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-32.fc46 ]]
