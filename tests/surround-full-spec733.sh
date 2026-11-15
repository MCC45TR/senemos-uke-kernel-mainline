#!/usr/bin/bash
# Data-only recipe comparison; no compiler or target operation.
set -Eeuo pipefail
owner=$(realpath "${1:?Source owner}")
parent=$(realpath "${2:?Admitted full11 spec}")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/packaging/native/rewrite-surround-full733.sh" "$parent" "$work/full12.spec" "$owner/manifests/cumulative-release.json"
node - "$parent" "$work/full12.spec" <<'NODE'
const fs=require('fs'),[a,b]=process.argv.slice(2),before=fs.readFileSync(a,'utf8'),after=fs.readFileSync(b,'utf8');
const source='bash native-profile/packaging/native/prepare-surround-full733.sh "$PWD" %{_uke_out} source\n';
const linked='bash native-profile/packaging/native/prepare-surround-full733.sh "$PWD" %{_uke_out} linked\n';
const install='bash native-profile/packaging/native/prepare-surround-full733.sh "$PWD" %{_uke_out} install \'%{buildroot}\'\n';
let inverse=after.replace(/^%global senemos_build_release (1[2-9]|[2-9][0-9]+)$/m,'%global senemos_build_release 11');
for(const line of [source,linked,install]){if(inverse.split(line).length!==2)throw Error('Missing/duplicate delivery phase');inverse=inverse.replace(line,'');}
inverse=inverse.replace(/(%changelog\n)\* Tue Nov 10 2026 Uke contributors - 7[.]3[.]3-[0-9]+\n- Render six\/eight program channels to four protected internal speakers[.]\n- Freeze amplifier work across system sleep and retain the quad fallback[.]\n\n/,'$1');
if(inverse!==before)throw Error('Existing full11 recipe/gate changed');
if(after.indexOf(source)>after.indexOf('bash boot-recipe/src/boot/build-payload.sh'))throw Error('Source must precede Image');
if(after.indexOf(install)<after.indexOf('bash native-profile/src/audio/desktop/install-policy.sh'))throw Error('Install must follow existing policy');
console.log('Full12 recipe: three additive phases, central release and changelog only; complete full11 inverse and gate order passed.');
NODE
cp "$parent" "$work/stale.spec"
printf '\n# stale input\n' >> "$work/stale.spec"
if bash "$owner/packaging/native/rewrite-surround-full733.sh" "$work/stale.spec" "$work/refused.spec" "$owner/manifests/cumulative-release.json" > "$work/refused.log" 2>&1;then exit 1;fi
printf 'Changed-parent full recipe refused; no original gate removed.\n'
