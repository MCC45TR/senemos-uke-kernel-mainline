#!/usr/bin/bash
# Data-only RPM scope regressions; no build or device operation.
set -Eeuo pipefail
[[ $# == 1 ]]
node - "$1" <<'NODE'
const fs=require('fs'),s=fs.readFileSync(process.argv[2],'utf8'),declaration='battery_event_parent=$(bash native-profile/packaging/native/battery-event-legacy-view733.sh "$PWD")\n';
function check(text){for(const phase of ['check','install']){const marker='\n%'+phase+'\n';if(text.split(marker).length!==2)throw Error('Phase');const block=text.split(marker)[1].split(/\n%[a-z]/)[0],mode=phase==='check'?'linked':'install';if(block.split(declaration).length!==2||!block.includes('prepare-charge-online-full733.sh "$battery_event_parent" %{_uke_out} '+mode)||!block.includes('prepare-battery-event-full733.sh "$PWD" %{_uke_out} '+mode))throw Error('Wrong battery source scope');}if(text.split('prepare-battery-event-full733.sh "$PWD" %{_uke_out} source\n').length!==2)throw Error('Source phase');}
check(s);for(const phase of ['check','install']){const marker='\n%'+phase+'\n',at=s.indexOf(marker),bad=s.slice(0,at)+s.slice(at).replace(declaration,'');let refused=false;try{check(bad);}catch{refused=true;}if(!refused)throw Error('Missing local scope accepted');}console.log('Battery event recipe: both independent parent scopes and missing-scope refusals pass; final production source stays new.');
NODE
