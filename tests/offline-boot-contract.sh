#!/usr/bin/env bash
# Host-only fixtures of the actual native switch-root decision; never boot.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
${CXX:-c++} -std=c++17 -Wall -Wextra -Werror "$root/src/boot/offline-switch-root.cpp" -o "$work/switch-root"
fixture=$work/root
mkdir -p "$fixture"/{proc,sys/firmware/devicetree/base/chosen,sysroot/usr/libexec,sysroot/usr/lib/systemd/system}
printf 'xiaomi,uke\0qcom,sm7675\0' > "$fixture/sys/firmware/devicetree/base/compatible"
printf 'root=PARTLABEL=linux systemd.unit=multi-user.target\n' > "$fixture/proc/cmdline"
"$work/switch-root" --inspect "$fixture" | jq -e '.executed==false and .charger_target_selected==false' >/dev/null
printf 'androidboot.mode = "charger"\n' > "$fixture/proc/bootconfig"
"$work/switch-root" --inspect "$fixture" | jq -e '.charger_signal==true and .charger_target_selected==false' >/dev/null
touch "$fixture/sysroot/usr/lib/systemd/system/uke-offline-charge."{service,target}
printf 'fixture only\n' > "$fixture/sysroot/usr/libexec/uke-offline-charge"
chmod 755 "$fixture/sysroot/usr/libexec/uke-offline-charge"
if [[ $(id -u) == 0 ]]; then
    "$work/switch-root" --inspect "$fixture" | jq -e '.executed==false and .matched_payload==true and .charger_target_selected==true' >/dev/null
    chmod g+w "$fixture/sysroot/usr/lib/systemd/system/uke-offline-charge.target"
    "$work/switch-root" --inspect "$fixture" | jq -e '.matched_payload==false and .charger_target_selected==false' >/dev/null
    chmod g-w "$fixture/sysroot/usr/lib/systemd/system/uke-offline-charge.target"
else
    "$work/switch-root" --inspect "$fixture" | jq -e '.matched_payload==false and .charger_target_selected==false' >/dev/null
    echo 'Positive root-owned fixture requires a root build sandbox; ordinary-user payload refusal passed'
fi
printf 'androidboot.mode=normal\n' > "$fixture/sys/firmware/devicetree/base/chosen/bootargs"
"$work/switch-root" --inspect "$fixture" | jq -e '.conflicting_signal==true and .charger_target_selected==false' >/dev/null
printf 'OtherBoard\0qcom,sm7675\0' > "$fixture/sys/firmware/devicetree/base/compatible"
"$work/switch-root" --inspect "$fixture" | jq -e '.charger_target_selected==false' >/dev/null
echo 'Actual switch-root decision preserves normal boot, refuses missing/unsafe payload and conflicting signals; no exec or device access'
