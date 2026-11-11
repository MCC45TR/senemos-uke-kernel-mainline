#!/usr/bin/bash
# The RPM phase shells must declare each authenticated source view locally.
set -Eeuo pipefail
[[ $# == 1 ]]
bash "$(dirname -- "$0")/quaternion-buffer-recipe-scope.sh" "$1"
node - "$1" <<'JS'
const fs=require('fs');function check(text){let phase='',declared=false,refs=0;const phases=[];for(const line of text.split('\n')){const m=line.match(/^%(prep|build|check|install)(?:\s|$)/);if(m){phase=m[1];declared=false;}if(line.startsWith('heading_parent=')){if(declared)throw Error('Duplicate declaration');declared=true;phases.push(phase);}if(line.includes('$heading_parent')){if(!declared)throw Error('Unscoped');refs++;}}if(refs!==4||phases.join(',')!=='check,install')throw Error('Incomplete scopes');}
const text=fs.readFileSync(process.argv[2],'utf8');check(text);for(const phase of ['check','install']){let current='';const mutant=text.split('\n').filter(l=>{const m=l.match(/^%(prep|build|check|install)(?:\s|$)/);if(m)current=m[1];return !(current===phase&&l.startsWith('heading_parent='));}).join('\n');let refused=false;try{check(mutant)}catch(e){if(e.message!=='Unscoped')throw e;refused=true;}if(!refused)throw Error('Missing declaration admitted');}console.log('Actual heading recipe: both RPM parent scopes and missing-declaration refusals pass; earlier layers retained.');
JS
