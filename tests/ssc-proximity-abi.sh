#!/usr/bin/bash
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared source}")
profile=$kernel/native-profile
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
awk '$0~/^static ssize_t ssc_proximity_input_abi_show[(]/{emit=1}emit{print}emit&&/^}/{n++;exit}END{if(n!=1)exit 1}' \
 "$kernel/drivers/iio/common/uke-ssc/uke-ssc-iio.c" > "$work/actual-proximity-abi.inc"
cp "$work/actual-proximity-abi.inc" "$work/good.inc"
ulimit -c 0
for cc in gcc clang;do
 for mode in 0 1;do
  flags=(-std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -Wno-unused-parameter)
  [[ $mode == 0 ]] || flags+=(-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
  "$cc" "${flags[@]}" -I"$work" "$profile/tests/ssc-proximity-abi.c" -o "$work/check"
  "$work/check"
  printf 'Proximity ABI callbacks passed:%s/sanitize%s; no hardware.\n' "$cc" "$mode"
 done
 for bad in undeclared hidden;do
  if [[ $bad == undeclared ]];then
   sed 's/s->declared \&\&/true \&\&/' "$work/good.inc" > "$work/actual-proximity-abi.inc"
  else
   sed 's/"1\\n"/"0\\n"/' "$work/good.inc" > "$work/actual-proximity-abi.inc"
  fi
  "$cc" -std=gnu11 -O2 -Wall -Wextra -Werror -UNDEBUG -Wno-unused-parameter -I"$work" "$profile/tests/ssc-proximity-abi.c" -o "$work/bad"
  result=0;"$work/bad" > "$work/bad.log" 2>&1 || result=$?
  # Undeclared/NULL dereference and false-negative capability must both fail.
  [[ $result == 134 || ($bad == undeclared && $result == 139) ]]
  printf 'Proximity ABI regression refused:%s/%s/status%s.\n' "$cc" "$bad" "$result"
  cp "$work/good.inc" "$work/actual-proximity-abi.inc"
 done
done
