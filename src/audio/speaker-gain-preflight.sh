#!/usr/bin/env bash
# Read-only preparation report. Never opens calibration or authorizes gain243.
set -Eeuo pipefail
export LC_ALL=C
if [[ $# == 1 && $1 == --help ]]; then
 printf '%s\n' 'Usage: uke-speaker-gain-preflight [--json]' \
  'Reports metadata only; exits2 while physical qualification is incomplete.'
 exit 0
fi
[[ $# == 0 || ( $# == 1 && $1 == --json ) ]] || exit 1
release=$(uname -r)
[[ $release =~ ^[0-9]+[.][0-9]+[.][0-9]+-[0-9]+(-unstable)?$ ]] || release=unknown
model=false
if [[ -r /sys/firmware/devicetree/base/compatible ]] &&
 tr '\0' '\n' < /sys/firmware/devicetree/base/compatible | grep -Fxq xiaomi,uke; then model=true; fi
persist_ro=false
if options=$(findmnt -nr -M /mnt/vendor/persist -o OPTIONS 2>/dev/null); then
 [[ ,$options, != *,ro,* ]] || persist_ro=true
fi
installed=false
if rpm -q uke-speaker-runtime >/dev/null 2>&1; then installed=true; fi
controls=false
controls_query=false
if names=$(amixer -c POCOPadX1 controls 2>/dev/null); then
 controls_query=true
 if grep -Fq "name='FS19xx Runtime Provisioning'" <<< "$names" &&
  grep -Fq "name='FS19xx Protection State'" <<< "$names"; then controls=true; fi
fi
native=null
if [[ -x /usr/bin/uke-speaker-runtime ]]; then
 result=0
 report=$(timeout 5 /usr/bin/uke-speaker-runtime --gain-readiness 2>/dev/null) || result=$?
 if [[ $result == 2 && ${#report} -le 8192 ]]; then
  native=$(jq -ce 'select(.schema_version==1 and .decision=="blocked" and
   .requested_gain_ceiling==243 and .binary_gain_ceiling==223 and
   .gain_243_admissible==false and .physical_protection_qualified==false and
   (.authenticated_interface|type)=="boolean" and (.provisioned|type)=="boolean" and
   (.protected_graph_running|type)=="boolean" and (.protection_state|type)=="string" and
   (.physical_evidence|type)=="object" and (.physical_evidence|length)==8 and
   (.physical_evidence|all(.=="unverified"))) |
   {authenticated_interface,provisioned,protected_graph_running,protection_state}' <<< "$report") || native=null
 fi
fi
jq -n --arg release "$release" --argjson model "$model" --argjson ro "$persist_ro" \
 --argjson installed "$installed" --argjson controls "$controls" --argjson query "$controls_query" --argjson native "$native" '
 {schema_version:1,kernel_release:$release,model_matched:$model,
  requested_gain_ceiling:243,gain_243_admissible:false,decision:"blocked",
  persist_mount_read_only:$ro,runtime_installed:$installed,
  controls_query_succeeded:$query,protected_controls_visible:$controls,native_readiness:$native,
  blockers: ([if $model then empty else "model_not_matched" end,
   if $ro then empty else "persist_not_verified_read_only" end,
   if $installed then empty else "runtime_not_installed" end,
   if ($query|not) then "protected_kernel_controls_unavailable"
    elif $controls then empty else "protected_kernel_controls_missing" end,
   if $native==null then "authenticated_runtime_readiness_unavailable" else empty end,
   if ($native.provisioned // false) then empty else "calibration_provisioning_unverified" end,
   if ($native.protected_graph_running // false) then empty else "protected_graph_not_observed_running" end] +
   ["dsp_protection_mode_unverified","electrical_calibration_and_physical_binding_unverified",
    "gain_transfer_function_unverified","vi_mapping_scaling_continuity_unverified","power_limit_unverified",
    "coil_temperature_limit_unverified","excursion_limit_unverified",
    "fault_response_deadline_unverified","gain243_final_writer_not_admitted"])}'
exit 2
