#!/usr/bin/bash
# Pure-text additive recipe transform; source/runtime acceptance is separate.
set -Eeuo pipefail
[[ $# == 3 ]]
input=$1
output=$2
tuple=$(bash "$(dirname -- "$0")/../../scripts/kernel-release.sh" json "$3")
release=$(jq -er '.release|select(.==13)' <<< "$tuple")
[[ $(jq -er .version <<< "$tuple") == 7.3.3 && ! -e $output ]]
printf '%s  %s\n' b85fdf18606c2b52dbf35b0755b9884deeec872878b36ff7cf2f683de37e026e "$input" | sha256sum -c --strict --quiet -
awk -v release="$release" '
 /^SourceLicense: / {print $0 " AND LGPL-2.0-or-later";license++;next}
 $0=="%global senemos_build_release 12" {print "%global senemos_build_release "release;r++;next}
 $0=="bash native-profile/packaging/native/prepare-surround-full733.sh \"$PWD\" %{_uke_out} source" {print;print "bash native-profile/packaging/native/prepare-pcm-surround-full733.sh \"$PWD\" %{_uke_out} source";s++;next}
 $0=="bash native-profile/packaging/native/prepare-surround-full733.sh \"$PWD\" %{_uke_out} linked" {print;print "bash native-profile/packaging/native/prepare-pcm-surround-full733.sh \"$PWD\" %{_uke_out} linked";l++;next}
 $0=="bash native-profile/packaging/native/prepare-surround-full733.sh \"$PWD\" %{_uke_out} install '\''%{buildroot}'\''" {print;print "bash native-profile/packaging/native/prepare-pcm-surround-full733.sh \"$PWD\" %{_uke_out} install '\''%{buildroot}'\''";i++;next}
 $0=="%changelog" {
  print;print "* Tue Nov 10 2026 Uke contributors - 7.3.3-"release
  print "- Fix semantic UCM IDs and bounded eight-channel PCM transport."
  print "- Correct media lengths while preserving protected quad outputs and gain223."
  print "";c++;next
 }
 {print}
 END{if(r!=1||s!=1||l!=1||i!=1||c!=1||license!=1)exit 1}
' "$input" > "$output"
node - "$input" "$output" <<'NODE'
const fs=require('fs'),[a,b]=process.argv.slice(2),before=fs.readFileSync(a,'utf8'),after=fs.readFileSync(b,'utf8');
let inverse=after.replace(/^%global senemos_build_release 13$/m,'%global senemos_build_release 12').replace(/^(SourceLicense: .*) AND LGPL-2[.]0-or-later$/m,'$1');
for(const phase of ['source','linked','install']){const line='bash native-profile/packaging/native/prepare-pcm-surround-full733.sh "$PWD" %{_uke_out} '+phase+(phase==='install'?" '%{buildroot}'":'')+'\n';if(inverse.split(line).length!==2)throw Error('New phase count');inverse=inverse.replace(line,'');}
inverse=inverse.replace(/(%changelog\n)\* Tue Nov 10 2026 Uke contributors - 7[.]3[.]3-13\n- Fix semantic UCM IDs and bounded eight-channel PCM transport[.]\n- Correct media lengths while preserving protected quad outputs and gain223[.]\n\n/,'$1');
if(inverse!==before)throw Error('Existing full12 recipe/gate changed');
console.log('Full13 recipe: complete full12 inverse, three additive PCM/UCM phases, central revision only; all old gates retained.');
NODE
