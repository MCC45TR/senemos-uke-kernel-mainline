#!/usr/bin/bash
# Preserve the complete successful native30 recipe through a whole-file inverse.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' 6677694fcb041a33d91a404a21fcd5d241fb07b669915dcdc4137f0e4976fe0c "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CSID_IRQ31_CHECK_BEGIN
tar -xJf %{SOURCE216}
(cd csid-irq734;sha256sum -c --strict --quiet SHA256SUMS)
bash csid-irq734/tests/native-csid-irq734.sh "$PWD" "$PWD/stable734-objects" "$PWD/csid-irq734" "$PWD/csid-irq734-result"
csid_support=%{buildroot}%{_datadir}/%{name}/csid-irq734
install -d "$csid_support"
install -m644 csid-irq734-result/{source.sha256,native-objects.sha256,results.txt,qualification.json} csid-irq734/{source-commit,SHA256SUMS} "$csid_support/"
install -m644 csid-irq734/src/camera/csid-irq734/{pre.sha256,post.sha256,irq.patch} "$csid_support/"
install -m644 csid-irq734-result/model/after/actual-oracle.h "$csid_support/oem-fields.h"
sha256sum -c --strict --quiet csid-irq734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CSID_IRQ31_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CSID_IRQ31_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-31";print "- Qualify the exact SM7675 reset and completion IRQ hierarchy with unchanged legacy traces.";print "";print "# UKE_CSID_IRQ31_HISTORY_END";next}
 !history&&$0=="Release: 30%{?dist}"{$0="Release: 31%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_CSID_IRQ31_HEADER_BEGIN";print "Source216: uke-csid-irq734.tar.xz";print "# UKE_CSID_IRQ31_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CSID_IRQ31_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CSID_IRQ31_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 31%{?dist}"{$0="Release: 30%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-31.fc46 ]]
