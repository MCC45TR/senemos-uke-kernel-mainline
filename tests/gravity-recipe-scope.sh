#!/usr/bin/bash
# Data-only RPM shell-scope check with an actual failed-recipe control.
set -Eeuo pipefail
[[ $# == 1 || $# == 2 ]]
node - "$@" <<'NODE'
const fs=require('fs');
function check(p){
 let phase='',declared=false,references=0;
 for(const line of fs.readFileSync(p,'utf8').split('\n')){
  const section=line.match(/^%(prep|build|check|install)(?:\s|$)/);
  if(section){phase=section[1];declared=false;}
  if(line.startsWith('gravity_parent='))declared=true;
  if(line.includes('$gravity_parent')){
   if(!declared)throw Error('Unscoped gravity parent in RPM '+phase+' shell');
   references++;
  }
 }
 if(references!==10)throw Error('Expected nine SSC calls plus one ABI comparison');
}
check(process.argv[2]);
console.log('Actual gravity recipe: all ten parent-text references are declared in their own RPM phase shell.');
if(process.argv[3]){
 let refused=false;
 try{check(process.argv[3]);}catch(e){if(!String(e.message).startsWith('Unscoped gravity parent'))throw e;refused=true;}
 if(!refused)throw Error('Historical cross-phase recipe admitted');
 console.log('Actual failed full14 recipe refused: build-shell variables do not survive the RPM check shell.');
}
NODE
