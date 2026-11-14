#!/usr/bin/bash
# Data-only RPM shell scope check; actual native regressions run in COPR.
set -Eeuo pipefail
[[ $# == 1 ]]
bash "$(dirname -- "$0")/quaternion-recipe-scope.sh" "$1"
node - "$1" <<'NODE'
const fs=require('fs');function check(text){let phase='',declared=false,refs=0;const phases=[];for(const line of text.split('\n')){const m=line.match(/^%(prep|build|check|install)(?:\s|$)/);if(m){phase=m[1];declared=false;}if(line.startsWith('buffer_parent=')){if(declared)throw Error('Duplicate');declared=true;phases.push(phase);}if(line.includes('$buffer_parent')){if(!declared)throw Error('Unscoped');refs++;}}if(refs!==4||phases.join(',')!=='check,install')throw Error('Incomplete scopes');}
const text=fs.readFileSync(process.argv[2],'utf8');check(text);for(const phase of ['check','install']){let current='';const mutant=text.split('\n').filter(l=>{const m=l.match(/^%(prep|build|check|install)(?:\s|$)/);if(m)current=m[1];return !(current===phase&&l.startsWith('buffer_parent='));}).join('\n');let refused=false;try{check(mutant)}catch(e){if(e.message!=='Unscoped')throw e;refused=true;}if(!refused)throw Error('Missing declaration accepted');}console.log('Actual buffer recipe: both RPM scopes and missing-declaration refusals pass; retained quaternion/gravity scopes unchanged.');
NODE
