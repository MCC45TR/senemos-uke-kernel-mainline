#!/usr/bin/bash
# Preserve full8 exactly; add qualified receiver layers and read-only front access.
set -Eeuo pipefail
[[ $# == 2 ]]
before=$(realpath "$1");after=$(realpath -m "$2")
[[ ! -e $after && ! -L $after ]]
printf '%s  %s\n' bebc04e4c93f34f73a96877115548a4feeea0518e2993f3dd3faa9c5cdd13f21 "$before" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
cat > "$work/header" <<'SPEC'
# UKE_CAMERA_FULL7349_HEADER_BEGIN
Source224: uke-camera-full7349.tar.xz
Source225: camera-native32-proof.rpm
Source226: camera-full7349-qualification.json
# UKE_CAMERA_FULL7349_HEADER_END
SPEC
cat > "$work/prepare" <<'SPEC'
# UKE_CAMERA_FULL7349_PREPARE_BEGIN
tar -xJf %{SOURCE224}
(cd camera-full7349;sha256sum -c --strict --quiet SHA256SUMS)
# UKE_CAMERA_FULL7349_PREPARE_END
SPEC
cat > "$work/build" <<'SPEC'
# UKE_CAMERA_FULL7349_BUILD_BEGIN
printf '%s  %s\n' "$(jq -er .native.proof_sha256 %{SOURCE226})" %{SOURCE225} | sha256sum -c --strict --quiet -
mkdir native-generated/camera-native32-proof
(cd native-generated/camera-native32-proof;rpm2cpio %{SOURCE225} | cpio -idm --quiet --no-absolute-filenames --no-preserve-owner)
receive_proof=$PWD/native-generated/camera-native32-proof/usr/share/uke-kernel-migration-check
for name in camss-lite734 phy-power734 csid-irq734 csid-stream734;do
 layer=$PWD/camera-full7349/$name
 proof=$receive_proof/$name
 test "$(cat "$layer/source-commit")" = "$(jq -er --arg name "$name" '.qualified_layers[]|select(.name==$name)|.source_commit' %{SOURCE226})"
 cmp "$proof/source-commit" "$layer/source-commit"
 cmp "$proof/SHA256SUMS" "$layer/SHA256SUMS"
 case "$name" in
  camss-lite734) script=native-camss-lite734.sh;;
  phy-power734) script=native-phy-power734.sh;;
  csid-irq734) script=native-csid-irq734.sh;;
  csid-stream734) script=native-csid-stream734.sh;;
 esac
 bash "$layer/tests/$script" "$PWD" "$super_objects" "$layer" "$PWD/$name-result"
 cmp "$proof/qualification.json" "$name-result/qualification.json"
 sha256sum -c --strict --quiet "$proof/source.sha256"
done
bash camera-full7349/tests/native-front-eeprom734.sh "$PWD" "$super_objects" "$PWD/camera-full7349" "$PWD/front-eeprom734-result"
bash camera-full7349/seal-camera-full7349.sh "$PWD"
# UKE_CAMERA_FULL7349_BUILD_END
SPEC
cat > "$work/linked" <<'SPEC'
# UKE_CAMERA_FULL7349_LINKED_BEGIN
sha256sum -c --strict --quiet camera-full7349-result/source.sha256
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/boot/Image
grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/kernel/uke-abl.o
llvm-nm %{_uke_out}/drivers/clk/qcom/camcc-sm7675.o | awk '$NF=="qcom_sm7675_camcc_status"{found=1}END{exit !found}'
(cd %{_uke_out};sha256sum arch/arm64/kernel/uke-abl.o drivers/clk/qcom/camcc-sm7675.o drivers/media/platform/qcom/camss/{camss,camss-csiphy,camss-vfe-gen3,camss-csid,camss-csid-gen3}.o arch/arm64/boot/Image vmlinux) > camera-full7349-result/full-linked.sha256
# UKE_CAMERA_FULL7349_LINKED_END
SPEC
cat > "$work/check" <<'SPEC'
# UKE_CAMERA_FULL7349_CHECK_BEGIN
sha256sum -c --strict --quiet camera-full7349-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full7349-result/full-linked.sha256")
jq -e '.compiler_modes==4 and .readonly_eeprom_only and .controller_then_quarantine_then_front and (.physical_camera_accepted|not)' front-eeprom734-result/qualification.json
# UKE_CAMERA_FULL7349_CHECK_END
SPEC
cat > "$work/install" <<'SPEC'
# UKE_CAMERA_FULL7349_INSTALL_BEGIN
sha256sum -c --strict --quiet camera-full7349-result/source.sha256
(cd %{_uke_out};sha256sum -c --strict --quiet "$OLDPWD/camera-full7349-result/full-linked.sha256")
receive_support=%{buildroot}/usr/share/senemos/uke/%{krel}/build-support/camera-front7349
install -d "$receive_support"
install -m644 %{SOURCE226} "$receive_support/full-qualification.json"
install -m644 camera-full7349-result/*.sha256 "$receive_support/"
for name in camss-lite734 phy-power734 csid-irq734 csid-stream734 front-eeprom734;do
 install -d "$receive_support/$name"
 install -m644 "$name-result/"{source.sha256,native-objects.sha256,results.txt,qualification.json} "$receive_support/$name/"
done
install -m644 camera-full7349/src/camera/front-eeprom734/{pre.sha256,post.sha256,activation.patch} "$receive_support/front-eeprom734/"
# UKE_CAMERA_FULL7349_INSTALL_END
SPEC
awk -v root="$work" '
 function inject(name,path,line){path=root"/"name;while((getline line<path)>0)print line;close(path)}
 /^%changelog$/{history=1;print;print "# UKE_CAMERA_FULL7349_HISTORY_BEGIN";print "* Tue Nov 17 2026 Uke contributors - 7.3.4-9";print "- Admit the exact read-only front EEPROM route after controller boot qualification.";print "- Retain qualified lite VFE, scoped PHY supplies and CSID IRQ/stream lifecycle fixes.";print "";print "# UKE_CAMERA_FULL7349_HISTORY_END";next}
 !history{
  if($0=="%global senemos_build_release 8"){$0="%global senemos_build_release 9";release++}
  if($0=="%description"){inject("header");headers++}
  if($0=="# UKE_CAMERA_FULL7348_PREPARE_END"){print;inject("prepare");prepares++;next}
  if($0=="# UKE_CAMERA_FULL7348_BUILD_END"){print;inject("build");builds++;next}
  if($0=="bash camera-full7348/verify-parent-source-tuple7348.sh \"$PWD\" \"$native_proof/source.sha256\""){
   print "# UKE_CAMERA_FULL7349_TUPLE_BEGIN";print "bash camera-full7349/verify-parent-source-tuple7349.sh \"$PWD\" \"$native_proof/source.sha256\"";print "# UKE_CAMERA_FULL7349_TUPLE_END";tuples++;next
  }
  if($0=="# UKE_CAMERA_FULL7348_LINKED_END"){print;inject("linked");links++;next}
  if($0=="%check"){print;inject("check");checks++;next}
  if($0=="%install"){print;inject("install");installs++;next}
  if(index($0,"Front EEPROM must remain inactive in this bisection stage")){
   print "# UKE_CAMERA_FULL7349_ADMISSION_BEGIN";print "grep -aqF uke-front-calibration %{_uke_out}/arch/arm64/boot/Image";print "# UKE_CAMERA_FULL7349_ADMISSION_END";admits++;next
  }
 }{print}END{if(release!=1||headers!=1||prepares!=1||builds!=1||tuples!=1||links!=1||checks!=1||installs!=1||admits!=1)exit 1}
' "$before" > "$after"
awk '
 /^# UKE_CAMERA_FULL7349_TUPLE_END$/{print "bash camera-full7348/verify-parent-source-tuple7348.sh \"$PWD\" \"$native_proof/source.sha256\"";skip=0;next}
 /^# UKE_CAMERA_FULL7349_ADMISSION_END$/{print "if grep -aqF '\''uke-front-calibration'\'' %{_uke_out}/arch/arm64/boot/Image; then echo '\''Front EEPROM must remain inactive in this bisection stage'\'' >&2; exit 1; fi";skip=0;next}
 /^# UKE_CAMERA_FULL7349_[A-Z]+_BEGIN$/{skip=1;next}
 /^# UKE_CAMERA_FULL7349_[A-Z]+_END$/{skip=0;next}
 skip{next}
 /^%changelog$/{history=1}
 !history&&$0=="%global senemos_build_release 9"{$0="%global senemos_build_release 8"}
 {print}
' "$after" | cmp - "$before"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$after") == senemos-uke-linux-kernel-mainline-unstable-7.3.4-9.fc46 ]]
