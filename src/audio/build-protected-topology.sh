#!/usr/bin/env bash
# COPR-only topology generation. Does not change the default installed profile.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")" && pwd)
output=${1:?Generated topology configuration}
awk '
    /^SectionVendorTokens\."audioreach_tokens"/ {tokens=1}
    tokens && /^}/ {
        print "    AR_TKN_U32_MODULE_CTRL_PORT_ID \"4000\""
        print "    AR_TKN_U32_MODULE_CTRL_PEER_INSTANCE_ID \"4001\""
        print "    AR_TKN_U32_MODULE_CTRL_PEER_PORT_ID \"4002\""
        print "    AR_TKN_U32_MODULE_CTRL_INTENT_ID \"4003\""
        print "    AR_TKN_U32_MODULE_CTRL_HEAP_ID \"4004\""
        tokens=0
    }
    /^SectionVendorTuples\."spk_tdm_sink"/ {exit}
    /^# This graph omits/ {next}
    {print}' "$owner/POCO-Pad-X1.conf" > "$output"
cat >> "$output" <<'CONF'
# Calibrated FourSemi RX and its VI TX peer share backend graph 40.
SectionVendorTuples."vi_device_sg" {
    tokens "audioreach_tokens"
    tuples."word.u32_data" {
        AR_TKN_DAI_INDEX "40"
        AR_TKN_U32_SUB_GRAPH_INSTANCE_ID "0x4013"
        AR_TKN_U32_SUB_GRAPH_PERF_MODE "2"
        AR_TKN_U32_SUB_GRAPH_DIRECTION "2"
        AR_TKN_U32_SUB_GRAPH_SCENARIO_ID "1"
    }
}
SectionData."vi_device_sg" { tuples "vi_device_sg" }
SectionVendorTuples."vi_device_container" {
    tokens "audioreach_tokens"
    tuples."word.u32_data" {
        AR_TKN_U32_CONAINER_INSTANCE_ID "0x5013"
        AR_TKN_U32_CONAINER_CAPABILITY_ID "0x0b001001"
        AR_TKN_U32_CONAINER_STACK_SIZE "16384"
        AR_TKN_U32_CONAINER_GRAPH_POS "4"
        AR_TKN_U32_CONAINER_PROC_DOMAIN "2"
    }
}
SectionData."vi_device_container" { tuples "vi_device_container" }
CONF
module() {
    local name=$1 mid=$2 iid=$3 inputs=$4 outputs=$5 destination=$6 group=$7 container=$8
    cat >> "$output" <<CONF
SectionVendorTuples."$name" {
    tokens "audioreach_tokens"
    tuples."word.u32_data" {
        AR_TKN_U32_MODULE_ID "$mid"
        AR_TKN_U32_MODULE_INSTANCE_ID "$iid"
        AR_TKN_U32_MODULE_MAX_IP_PORTS "$inputs"
        AR_TKN_U32_MODULE_MAX_OP_PORTS "$outputs"
        AR_TKN_U32_MODULE_SRC_INSTANCE_ID "$iid"
        AR_TKN_U32_MODULE_SRC_OP_PORT_ID "$([[ $destination != 0 ]] && printf 1 || printf 0)"
        AR_TKN_U32_MODULE_DST_INSTANCE_ID "$destination"
        AR_TKN_U32_MODULE_DST_IN_PORT_ID "$([[ $destination != 0 ]] && printf 2 || printf 0)"
$(if [[ $name == spk.fs.rx ]]; then cat <<'TOKENS'
        AR_TKN_U32_MODULE_CTRL_PORT_ID "0x80000000"
        AR_TKN_U32_MODULE_CTRL_PEER_INSTANCE_ID "0x49fd"
        AR_TKN_U32_MODULE_CTRL_PEER_PORT_ID "0x80000000"
        AR_TKN_U32_MODULE_CTRL_INTENT_ID "0x08001231"
        AR_TKN_U32_MODULE_CTRL_HEAP_ID "1"
TOKENS
fi)
    }
}
SectionData."$name" { tuples "$name" }
SectionWidget."$name" {
    index "40"
    type "src"
    no_pm "true"
    subseq "10"
    data [ "$group" "$container" "$name" ]
}
CONF
}
module spk.mfc 0x07001015 0x442e 1 1 0x4040 spk_device_sg spk_device_container
module spk.fs.rx 0x10001111 0x4040 1 1 0x4433 spk_device_sg spk_device_container
module spk.fs.tx 0x10001110 0x49fd 1 1 0 vi_device_sg vi_device_container
tdm() {
    local name=$1 mid=$2 iid=$3 inputs=$4 outputs=$5 destination=$6 group=$7 container=$8 lane=$9
    cat >> "$output" <<CONF
SectionVendorTuples."$name" {
    tokens "audioreach_tokens"
    tuples."word.u32_data" {
        AR_TKN_U32_MODULE_ID "$mid"
        AR_TKN_U32_MODULE_INSTANCE_ID "$iid"
        AR_TKN_U32_MODULE_MAX_IP_PORTS "$inputs"
        AR_TKN_U32_MODULE_MAX_OP_PORTS "$outputs"
        AR_TKN_U32_MODULE_SRC_INSTANCE_ID "$iid"
        AR_TKN_U32_MODULE_SRC_OP_PORT_ID "$([[ $destination != 0 ]] && printf 1 || printf 0)"
        AR_TKN_U32_MODULE_DST_INSTANCE_ID "$destination"
        AR_TKN_U32_MODULE_DST_IN_PORT_ID "$([[ $destination != 0 ]] && printf 2 || printf 0)"
        AR_TKN_U32_MODULE_FMT_DATA "1"
        AR_TKN_U32_MODULE_HW_IF_IDX "0"
        AR_TKN_U32_MODULE_HW_IF_TYPE "3"
        AR_TKN_U16_MODULE_SYNC_SRC "1"
        AR_TKN_U16_MODULE_CTRL_DATA_OUT_ENABLE "1"
        AR_TKN_U32_MODULE_SLOT_MASK "15"
        AR_TKN_U16_MODULE_NSLOTS_PER_FRAME "4"
        AR_TKN_U16_MODULE_SLOT_WIDTH "32"
        AR_TKN_U16_MODULE_SYNC_MODE "0"
        AR_TKN_U16_MODULE_CTRL_INVERT_SYNC_PULSE "0"
        AR_TKN_U16_MODULE_CTRL_SYNC_DATA_DELAY "1"
        AR_TKN_U32_MODULE_ACTIVE_LANE_MASK "$lane"
    }
}
SectionData."$name" { tuples "$name" }
SectionWidget."$name" {
    index "40"
    type "aif_in"
    no_pm "true"
    stream_name "Secondary TDM0 Playback"
    subseq "10"
    data [ "$group" "$container" "$name" ]
}
CONF
}
tdm spk.sink 0x0700100e 0x4433 1 0 0 spk_device_sg spk_device_container 2
tdm spk.vi.source 0x0700100f 0x4960 0 1 0x49fd vi_device_sg vi_device_container 1
awk '
    /^SectionControlMixer\."MultiMedia2"/ {copy=1}
    copy {
        if ($0 ~ /"spk.sink, , SECONDARY_TDM_RX_0 Audio Mixer"/) {
            print "        \"spk.mfc, , SECONDARY_TDM_RX_0 Audio Mixer\""
            print "        \"spk.fs.rx, , spk.mfc\""
            print "        \"spk.sink, , spk.fs.rx\""
            print "        \"spk.fs.tx, , spk.vi.source\""
        } else print
    }' "$owner/POCO-Pad-X1.conf" >> "$output"
