#!/usr/bin/bash
# Preserve the complete successful native27 recipe through a whole-file inverse.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 3b3b8d295f9fdc8f476486ece77497b7a1469b39f9a21652b07dc26afb004787 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_PHY_POWER30_CHECK_BEGIN
tar -xJf %{SOURCE215}
(cd phy-power734;sha256sum -c --strict --quiet SHA256SUMS)
bash phy-power734/tests/native-phy-power734.sh "$PWD" "$PWD/stable734-objects" "$PWD/phy-power734" "$PWD/phy-power734-result"
phy_power_support=%{buildroot}%{_datadir}/%{name}/phy-power734
install -d "$phy_power_support"
install -m644 phy-power734-result/{source.sha256,native-objects.sha256,results.txt,qualification.json} phy-power734/{source-commit,SHA256SUMS} "$phy_power_support/"
install -m644 phy-power734/src/camera/phy-power734/{pre.sha256,post.sha256,power.patch} "$phy_power_support/"
sha256sum -c --strict --quiet phy-power734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_PHY_POWER30_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_PHY_POWER30_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-30";print "- Qualify demand-scoped shared PHY supply votes, permanent ownership and cached controller admission.";print "";print "# UKE_PHY_POWER30_HISTORY_END";next}
 !history&&$0=="Release: 27%{?dist}"{$0="Release: 30%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_PHY_POWER30_HEADER_BEGIN";print "Source215: uke-phy-power734.tar.xz";print "# UKE_PHY_POWER30_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_PHY_POWER30_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_PHY_POWER30_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 30%{?dist}"{$0="Release: 27%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-30.fc46 ]]
