#!/usr/bin/bash
# Retain the whole qualified33 recipe; add the source-only HF admission gate.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' a67b34bdc614fc43fbf062bc1ecde9709a31f339ac5315e277cef7355e442bfb "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_ICC34_CHECK_BEGIN
tar -xJf %{SOURCE219}
(cd camera-icc-hf734;sha256sum -c --strict --quiet SHA256SUMS)
bash camera-icc-hf734/tests/native-camera-icc-hf734.sh "$PWD" "$PWD/stable734-objects" "$PWD/camera-icc-hf734" "$PWD/camera-icc-hf734-result"
icc_support=%{buildroot}%{_datadir}/%{name}/camera-icc-hf734
install -d "$icc_support"
install -m644 camera-icc-hf734-result/{source.sha256,native-objects.sha256,results.txt,qualification.json} camera-icc-hf734/{source-commit,SHA256SUMS} "$icc_support/"
install -m644 camera-icc-hf734/src/camera/icc-hf734/{pre.sha256,post.sha256,icc.patch} "$icc_support/"
sha256sum -c --strict --quiet camera-icc-hf734-result/source.sha256
test ! -e stable734-objects/arch/arm64/boot/Image
# UKE_CAMERA_ICC34_CHECK_END
SPEC
awk -v work="$work" '
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_ICC34_HISTORY_BEGIN";print "* Wed Nov 18 2026 Uke contributors - 7.3.4-34";print "- Verify initial BCM votes, QoS errors and the shared Cliffs camera HF route.";print "";print "# UKE_CAMERA_ICC34_HISTORY_END";next}
 !history&&$0=="Release: 33%{?dist}"{$0="Release: 34%{?dist}";releases++}
 !history&&$0=="%description"{print "# UKE_CAMERA_ICC34_HEADER_BEGIN";print "Source219: uke-camera-icc-hf734.tar.xz";print "# UKE_CAMERA_ICC34_HEADER_END";headers++}
 !history&&$0=="%files"{path=work"/check";while((getline line<path)>0)print line;close(path);checks++}
 {print}END{if(releases!=1||headers!=1||checks!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_ICC34_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_ICC34_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="Release: 34%{?dist}"{$0="Release: 33%{?dist}"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == uke-kernel-migration-check-7.3.4-34.fc46 ]]
