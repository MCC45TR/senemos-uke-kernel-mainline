#!/usr/bin/bash
# Preserve the entire successful native26 recipe through a complete inverse.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' cf2433fa939a958cf16247f5718a8ee7f3d4626f11303082c02305044d2e041f "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CAMSS_LITE27_CHECK_BEGIN
tar -xJf %{SOURCE214}
(cd camss-lite734;sha256sum -c --strict --quiet SHA256SUMS)
bash camss-lite734/tests/native-camss-lite734.sh "$PWD" "$PWD/stable734-objects" "$PWD/camss-lite734" "$PWD/camss-lite734-result"
camss_lite_support=%{buildroot}%{_datadir}/%{name}/camss-lite734
install -d "$camss_lite_support"
install -m644 camss-lite734-result/{source.sha256,native-objects.sha256,results.txt,qualification.json} camss-lite734/{source-commit,SHA256SUMS} "$camss_lite_support/"
install -m644 camss-lite734-result/model/after/actual-oem-oracle.h "$camss_lite_support/oem-register-oracle.h"
install -m644 camss-lite734/src/camera/camss-lite734/{pre.sha256,post.sha256,lite-testbus.patch} "$camss_lite_support/"
sha256sum -c --strict --quiet camss-lite734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CAMSS_LITE27_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CAMSS_LITE27_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-27";print "- Match the SM7675 lite VFE bus registers using independent GPL tables and production callback traces.";print "";print "# UKE_CAMSS_LITE27_HISTORY_END";next}
 !history&&$0=="Release: 26%{?dist}"{$0="Release: 27%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_CAMSS_LITE27_HEADER_BEGIN";print "Source214: uke-camss-lite734.tar.xz";print "# UKE_CAMSS_LITE27_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMSS_LITE27_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMSS_LITE27_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 27%{?dist}"{$0="Release: 26%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-27.fc46 ]]
