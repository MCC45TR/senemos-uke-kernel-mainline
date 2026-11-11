#!/usr/bin/env bash
# COPR only: real kernel callbacks and compiled topology, no DSP/amp operation.
set -Eeuo pipefail
ulimit -c 0
kernel=$(realpath "${1:?Prepared kernel source}")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
[[ ! -e /sys/firmware/devicetree/base/model ]]
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir "$work/new" "$work/mfc"
extract() { awk -v name="$1" '$0 ~ "^static .*"name"\\("{p=1} p{print} p&&/^}/{exit}' "$kernel/sound/soc/qcom/qdsp6/topology.c"; }
for name in audioreach_route_load audioreach_connect_sub_graphs;do
 extract "$name" > "$work/$name.c"
 [[ -s $work/$name.c ]]
 cat "$work/$name.c" >> "$work/actual-route-functions.h"
done
compiler=${CC:-gcc}
flags=(-std=gnu11 -O1 -g -Wall -Wextra -Werror -Wno-unused-parameter)
[[ ${SANITIZE:-0} != 1 ]] || flags+=(-fsanitize=address,undefined -fno-omit-frame-pointer)
"$compiler" "${flags[@]}" -I "$work" "$owner/tests/audio-protected-route.c" -o "$work/check"
metadata() {
 local directory=$1
 alsatplg -c "$directory/generated.conf" -o "$directory/topology.bin"
 alsatplg -d "$directory/topology.bin" -o "$directory/decoded.conf"
 awk '
 /^SectionVendorTuples \{/ {tuples=1;next}
 tuples && match($0,/^\t\047([^\047]+):tuple0\047 \{/,m) {
  name=m[1];depth=1;delete v;next
 }
 tuples && name!="" {
  if(match($0,/token([0-9]+) ([0-9]+)/,m))v[m[1]]=m[2]
  line=$0;depth+=gsub(/\{/,"",line)-gsub(/\}/,"",line)
  if(depth==0) {
   if(v[200])printf "%s\t%u\t%u\t%u\t%u\t%u\t%u\t%u\n",name,v[1],v[201],v[208],v[206],v[209],v[207],v[200]
   name=""
  }
 }' "$directory/decoded.conf" > "$directory/modules.tsv"
 awk '/^SectionGraph \{/{p=1} p&&match($0,/^\t\t\t\047([^\047]+)\047$/,m){print m[1]}' "$directory/decoded.conf" > "$directory/routes.txt"
 [[ -s $directory/modules.tsv && -s $directory/routes.txt ]]
}
cp "$owner/src/audio/build-protected-topology.sh" "$work/new/build-protected-topology.sh"
cp "$owner/src/audio/POCO-Pad-X1.conf" "$work/new/POCO-Pad-X1.conf"
bash "$work/new/build-protected-topology.sh" "$work/new/generated.conf"
metadata "$work/new"
"$work/check" "$work/new/modules.tsv" "$work/new/routes.txt"
# The other admitted baseline variant must produce identical protected data.
cp "$work/new/build-protected-topology.sh" "$work/mfc/build-protected-topology.sh"
awk '/"spk.sink, , SECONDARY_TDM_RX_0 Audio Mixer"/{print "        \"spk.mfc, , SECONDARY_TDM_RX_0 Audio Mixer\"";print "        \"spk.sink, , spk.mfc\"";changed++;next}{print} END{if(changed!=1)exit 1}' "$work/new/POCO-Pad-X1.conf" > "$work/mfc/POCO-Pad-X1.conf"
bash "$work/mfc/build-protected-topology.sh" "$work/mfc/generated.conf"
cmp "$work/new/generated.conf" "$work/mfc/generated.conf"
for mutation in missing duplicate;do
 mkdir "$work/$mutation"
 cp "$work/new/build-protected-topology.sh" "$work/$mutation/build-protected-topology.sh"
 awk -v mutation="$mutation" '/"spk.sink, , SECONDARY_TDM_RX_0 Audio Mixer"/{if(mutation=="missing")next;print}{print}' "$work/new/POCO-Pad-X1.conf" > "$work/$mutation/POCO-Pad-X1.conf"
 if bash "$work/$mutation/build-protected-topology.sh" "$work/$mutation/generated.conf" > "$work/$mutation/result.log" 2>&1;then exit 1;fi
 grep -Fx 'Protected speaker route is missing or ambiguous' "$work/$mutation/result.log"
done
if [[ ${SANITIZE:-0} == 0 ]];then
 mkdir "$work/original"
 cp "$owner/history-before-protected-route/src/audio/build-protected-topology.sh" "$work/original/build-protected-topology.sh"
 cp "$work/new/POCO-Pad-X1.conf" "$work/original/POCO-Pad-X1.conf"
 bash "$work/original/build-protected-topology.sh" "$work/original/generated.conf"
 metadata "$work/original"
 set +e
 "$work/check" "$work/original/modules.tsv" "$work/original/routes.txt" > "$work/original/refusal.log" 2>&1
 result=$?
 set -e
 [[ $result == 134 ]]
 grep -Fx 'Duplicate DSP input: 0x4433/2' "$work/original/refusal.log"
 printf 'Original protected route reproduces duplicate TDM input with actual Linux callbacks: %s/status134.\n' "$compiler"
fi
printf 'Protected route: actual Linux callbacks, compiled topology, both baseline forms and missing/duplicate refusal passed: %s/sanitize%s.\n' "$compiler" "${SANITIZE:-0}"
