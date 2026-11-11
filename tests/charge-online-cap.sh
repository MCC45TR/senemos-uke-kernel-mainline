#!/usr/bin/bash
# COPR only. Extract production callbacks; no runtime provider or battery access.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
profile=$kernel/native-profile
header=$kernel/drivers/power/supply/qcom_battmgr_uke_control.h
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
for item in 'scope qcom_battmgr_uke_apply_existing_cap_scope' 'offline qcom_battmgr_uke_apply_existing_cap' 'online-store uke_charge_apply_existing_cap_online_store';do
 read -r label function <<< "$item"
 awk -v name="$function" '$0~"^static (int|ssize_t) "name"[(]"{emit=1}emit{print}emit&&/^}/{n++;exit}END{if(n!=1)exit 1}' "$header" > "$work/actual-charge-$label.inc"
done
cp "$work/actual-charge-scope.inc" "$work/good.inc"
ulimit -c 0
for cc in gcc clang;do
 for sanitize in 0 1;do
  flags=(-std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -Wno-unused-parameter)
  [[ $sanitize == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/charge-online-cap.c" -o "$work/check"
  "$work/check"
  printf 'Online cap actual callbacks passed:%s/sanitize%s; no hardware acceptance.\n' "$cc" "$sanitize"
 done
 for bad in below_limit target online quarantine;do
  case $bad in
   below_limit) sed 's/battmgr->status.percent < 80/battmgr->status.percent < 1/' "$work/good.inc" > "$work/actual-charge-scope.inc";;
   target) sed 's/cpu_to_le32(80)/cpu_to_le32(100)/' "$work/good.inc" > "$work/actual-charge-scope.inc";;
   online) sed 's/online_reduction ? !battmgr->usb.online : battmgr->usb.online/online_reduction ? battmgr->usb.online : battmgr->usb.online/' "$work/good.inc" > "$work/actual-charge-scope.inc";;
   quarantine) sed 's/battmgr->control.preconfigured_uncertain = true/battmgr->control.preconfigured_uncertain = false/' "$work/good.inc" > "$work/actual-charge-scope.inc";;
  esac
  "$cc" -std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -Wno-unused-parameter -I"$work" "$profile/tests/charge-online-cap.c" -o "$work/bad"
  status=0;"$work/bad" > "$work/bad.log" 2>&1 || status=$?
  [[ $status == 134 ]]
  printf 'Online cap regression refused:%s/%s/status%s.\n' "$cc" "$bad" "$status"
  cp "$work/good.inc" "$work/actual-charge-scope.inc"
 done
done
