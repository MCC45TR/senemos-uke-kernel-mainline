#!/usr/bin/bash
# Native compilation is restricted to the COPR worker.
set -Eeuo pipefail
[[ $# == 3 && $(uname -m) == aarch64 && ! -e /etc/senemos/kernel-update.conf ]]
kernel=$(realpath "$1");source=$(realpath "$2");owner=$(realpath "$3")
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
node - "$kernel" "$source" "$owner" "$work" <<'JS'
const fs=require('fs'),a=require('assert/strict');
const [kernel,source,owner,work]=process.argv.slice(2);
const c=fs.readFileSync(source,'utf8'),core=fs.readFileSync(kernel+'/drivers/interconnect/core.c','utf8');
const oem=fs.readFileSync(owner+'/references/micode-cliffs.c','utf8');
function fun(s,name){
 const re=new RegExp('(?:^|\\n)(?:static )?(?:int|void) '+name+'\\([^;]*?\\)\\n\\{');
 const match=s.match(re);a(match,name);const start=match.index+(s[match.index]==='\n'?1:0),open=s.indexOf('{',start);
 let depth=1,end=open+1;for(;end<s.length&&depth;end++){if(s[end]==='{')depth++;if(s[end]==='}')depth--;}
 a.equal(depth,0);return s.slice(start,end)+'\n';
}
let out=c.slice(c.indexOf('/* QNOC QoS */'),c.indexOf('/**'));
for(const name of ['qcom_icc_set_qos','qcom_icc_pre_aggregate','qcom_icc_aggregate','qcom_icc_set','qcom_icc_bcm_init','qcom_icc_rpmh_configure_qos'])out+=fun(c,name);
out+=fun(core,'icc_node_add');fs.writeFileSync(work+'/actual-functions.c',out);
fs.copyFileSync(kernel+'/drivers/interconnect/qcom/cliffs-display-icc.h',work+'/cliffs-display-icc.h');
const qos=oem.slice(oem.indexOf('static struct qcom_icc_qosbox qnm_camnoc_hf_qos ='),oem.indexOf('static struct qcom_icc_node qnm_camnoc_hf ='));
const node=oem.slice(oem.indexOf('static struct qcom_icc_node qnm_camnoc_hf ='),oem.indexOf('static struct qcom_icc_qosbox qnm_camnoc_icp_qos ='));
const offsets=qos.match(/\.offsets = \{ (0x[0-9a-f]+), (0x[0-9a-f]+) \}/);a(offsets);
const channels=node.match(/\.channels = (\d+)/),width=node.match(/\.buswidth = (\d+)/);a(channels&&width);
a(qos.includes('.prio = 0')&&qos.includes('.urg_fwd = 1')&&qos.includes('.prio_fwd_disable = 0'));
a(node.includes('.links = { SLAVE_MNOC_HF_MEM_NOC }'));
const bcm=oem.slice(oem.indexOf('static struct qcom_icc_bcm bcm_mm1 ='),oem.indexOf('static struct qcom_icc_bcm bcm_qup0 ='));
a(bcm.includes('.enable_mask = 0x1')&&bcm.includes('&qnm_camnoc_hf')&&bcm.includes('&qns_mem_noc_sf'));
const patched=/bool sync_initial_votes\)/.test(c);
out='#define OEM_PORT0 '+offsets[1]+'\n#define OEM_PORT1 '+offsets[2]+'\n#define OEM_CHANNELS '+channels[1]+'\n#define OEM_BUSWIDTH '+width[1]+'\n';
out+='#define CONFIGURE(qp) qcom_icc_rpmh_configure_qos(qp'+(patched?',true':'')+')\n';
fs.writeFileSync(work+'/oracle.h',out);
// The complete caller remains in its native ARM64 object. Assert its exact
// dependency order here; execute the actual callee and ICC core in the fixture.
if(patched){
 a(c.includes('ret = qcom_icc_rpmh_configure_qos(qp, desc->qos_required);'));
 const init=c.indexOf('ret = qcom_icc_bcm_init(qp->bcms[i], dev);'),nodes=c.indexOf('for (i = 0; i < num_nodes; i++)'),map=c.indexOf('if (desc->config) {');
 a(init>0&&nodes>init&&map>nodes);
 a(c.slice(init,nodes).includes('return dev_err_probe(dev, ret,'));
 a(!c.includes('provider->get_bw ='));
}
JS
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror -Wno-sign-compare \
 ${ICC_HF_FLAGS:-} -include "$work/oracle.h" -I "$work" \
 "$owner/tests/fixtures/camera-icc-hf734.c" -o "$work/check"
"$work/check"
