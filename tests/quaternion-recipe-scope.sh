#!/usr/bin/bash
# Data-only check of both RPM shells and all retained gravity references.
set -Eeuo pipefail
[[ $# == 1 ]]
bash "$(dirname -- "$0")/gravity-recipe-scope.sh" "$1"
node - "$1" <<'NODE'
const fs=require('fs');
function check(text){
 let phase='',declared=false,refs=0;const declarations=[];
 for(const line of text.split('\n')){
  const section=line.match(/^%(prep|build|check|install)(?:\s|$)/);
  if(section){phase=section[1];declared=false;}
  if(line.startsWith('quaternion_parent=')){if(declared)throw Error('Duplicate phase declaration');declared=true;declarations.push(phase);}
  if(line.includes('$quaternion_parent')){if(!declared)throw Error('Unscoped quaternion parent');refs++;}
 }
 if(refs!==3||declarations.join(',')!=='check,install')throw Error('Incomplete parent-phase boundary');
}
const text=fs.readFileSync(process.argv[2],'utf8');check(text);
for(const phase of ['check','install']){
 let current='';const mutant=text.split('\n').filter(line=>{const m=line.match(/^%(prep|build|check|install)(?:\s|$)/);if(m)current=m[1];return !(current===phase&&line.startsWith('quaternion_parent='));}).join('\n');
 let refused=false;try{check(mutant);}catch(e){if(e.message!=='Unscoped quaternion parent')throw e;refused=true;}if(!refused)throw Error('Missing phase declaration admitted');
}
console.log('Actual quaternion recipe: check/install parent scopes and both missing-declaration controls pass; ten gravity references retained.');
NODE
