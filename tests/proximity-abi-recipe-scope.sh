#!/usr/bin/bash
# Check independent RPM shell scopes and keep the final production source new.
set -Eeuo pipefail
[[ $# == 1 ]]
node - "$1" <<'NODE'
const fs=require('fs'),spec=fs.readFileSync(process.argv[2],'utf8');
function verify(s){
 const declaration='proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$PWD")';
 for(const section of ['check','install']){
  const begin='\n%'+section+'\n';if(s.split(begin).length!==2)throw Error('RPM phase missing');const block=s.split(begin)[1].split(/\n%[a-z]/)[0];
  for(const line of [declaration,'heading_parent=$(bash native-profile/packaging/native/heading-legacy-view733.sh "$proximity_parent")'])if(block.split(line).length!==2)throw Error('Shell-local declaration missing');
  const phase=section==='check'?'linked':'install';if(!block.includes('prepare-heading-full733.sh "$proximity_parent" %{_uke_out} '+phase)||!block.includes('prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} '+phase))throw Error('Wrong actual source/module scope');
 }
 if(s.split('prepare-proximity-abi-full733.sh "$PWD" %{_uke_out} source\n').length!==2)throw Error('Source application missing/repeated');
}
verify(spec);
for(const section of ['check','install']){
 const begin='\n%'+section+'\n',at=spec.indexOf(begin),line='proximity_parent=$(bash native-profile/packaging/native/proximity-abi-legacy-view733.sh "$PWD")\n',body=spec.slice(at);if(!body.includes(line))throw Error('Negative fixture scope');const bad=spec.slice(0,at)+body.replace(line,'');let refused=false;try{verify(bad);}catch{refused=true;}if(!refused)throw Error('Missing declaration accepted');
}
console.log('Actual proximity recipe: both RPM parent scopes and missing-declaration refusals pass; earlier layers retained.');
NODE
