#!/usr/bin/bash
# Keep production and package gates; source regressions belong to the receipt.
set -Eeuo pipefail
[[ $# == 1 ]]
spec=$(realpath "${1:?Cumulative full spec}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
[[ $(grep -Fxc 'Name: senemos-uke-linux-kernel-mainline-unstable' "$spec") == 1 ]]
! grep -q UKE_LEAN_FULL_RECIPE "$spec"
awk '
 $0=="%build" {inbuild=1;print;print "# UKE_LEAN_FULL_RECIPE";skip=1;build++;next}
 skip && $0=="for role in cdsp waydroid cdsp-before; do"{reference=1;refs++}
 skip && reference {print;if($0=="done")reference=0;next}
 skip && /^bash native-profile\/packaging\/native\/prepare-memory-manager733.sh / {
   print;print "bash native-profile/packaging/native/check-dual-light-delivery733.sh \"$PWD\" %{_uke_out} prepared";skip=0;prepared++;next
 }
 skip{next}
 inbuild && /^bash native-profile\/tests\/(camcc-native-object|camss-sm7675-phy-object|camss-sm7675-module731-object|mainline-boot-status-contract|kernel-audio-policy-contract|usbss-kconfig-contract)[.]sh / {next}
 inbuild && /^CXX=clang[+][+] bash native-profile\/tests\/kernel-audio-policy-contract.sh/ {next}
 inbuild && /^make .* sound\/soc\/qcom\/uke-audio-card[.]o$/ {next}
 inbuild && /^bash native-profile\/src\/sensors\/apply-dual-light733.sh / {
   print;print "bash native-profile/src/audio/apply-speaker-display733.sh \"$PWD\"";route++;next
 }
 $0=="%check" {inbuild=0;check++;print;next}
 /^bash native-profile\/tests\/camcc-owner-object.sh /{next}
 /^bash native-profile\/tests\/wcd939x-telemetry-package-contract.sh /{
   print "bash native-profile/packaging/native/check-shipping-audio733.sh \"$PWD\" %{_uke_out} linked";audio++;next
 }
 $0=="uke_check_start=$SECONDS" {
   tail=1;print
   print "bash native-profile/tests/kernel-hardening-config-contract.sh %{_uke_out}/.config"
   print "bash native-profile/tests/kernel-module-signatures-contract.sh \"$PWD\" %{buildroot}/usr/lib/modules/%{krel} %{buildroot}/usr/share/senemos/uke/%{krel}/module-signing.x509"
   print "test ! -e %{_uke_out}/certs/signing_key.pem"
   print "bash native-profile/tests/unstable-boot-family731-contract.sh %{_specdir}/senemos-uke-linux-kernel-mainline-unstable.spec %{buildroot} %{krel}"
   print "test -s %{buildroot}%{_docdir}/%{name}/%{krel}/README.md"
   print "test ! -e %{buildroot}%{_docdir}/%{name}/README.md"
   print "printf '\''UKE_BUILD_STAGE package_checks elapsed_s=%d\\n'\'' \"$((SECONDS-uke_check_start))\""
   next
 }
 tail && $0=="%install"{tail=0;install++}
 tail{next}
 {print}
 END{if(build!=1||refs!=1||prepared!=1||route!=1||check!=1||audio!=1||install!=1||skip||reference||tail)exit 1}
' "$spec" > "$work/lean.spec"
# No feature/config/file/subpackage change; only phase bodies are replaced.
for boundary in prep install; do
 case $boundary in prep) start=1;stop=build;;install)start=0;stop=never;;esac
 for form in "$spec" "$work/lean.spec"; do
  awk -v part="$boundary" '
   part=="prep"&&$0=="%build"{exit}
   part=="prep"{print;next}
   part=="install"&&$0=="%install"{copy=1}
   part=="install"&&copy{print}
  ' "$form" > "$work/${boundary}-$(basename "$form")"
 done
 cmp "$work/${boundary}-$(basename "$spec")" "$work/${boundary}-lean.spec"
done
install -m644 "$work/lean.spec" "$spec"
printf 'Lean full recipe: exact prep/install/files retained; duplicate source and inspection compilations moved to same-source qualification; production/linked/signature gates retained.\n'
