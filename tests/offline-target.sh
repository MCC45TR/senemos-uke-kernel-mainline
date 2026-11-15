#!/usr/bin/env bash
# Native COPR qualification only. Never invoke SwitchRoot or a generator on /run.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
ulimit -c 0
for compiler in g++ clang++;do for sanitize in 0 1;do
 flags=(-std=c++17 -O1 -g -UNDEBUG -Wall -Wextra -Werror -fno-omit-frame-pointer)
 [[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
 "$compiler" "${flags[@]}" "$root/tests/offline-target.cpp" -o "$work/test"
 ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 timeout -k 1s 20s "$work/test"
 printf 'Actual offline target generator passed:%s/sanitize%s.\n' "$compiler" "$sanitize"
done;done
mkdir -p "$work/mutant/tests" "$work/mutant/src/boot/offline"
cp "$root/tests/offline-target.cpp" "$work/mutant/tests/"
cp "$root/src/boot/offline/"{io,boot-mode}.hpp "$work/mutant/src/boot/offline/"
for compiler in g++ clang++;do
 for mutant in ignore-mode ignore-marker writable-output hidden-collision;do
  cp "$root/src/boot/offline/target.hpp" "$work/mutant/src/boot/offline/target.hpp"
  source=$work/mutant/src/boot/offline/target.hpp
  case $mutant in
   ignore-mode) sed -i 's/boot_mode(root) != BootMode::charger || /false || /' "$source";;
   ignore-marker) sed -i 's/!trusted_handoff(root, owner)/false/' "$source";;
   writable-output) sed -i 's/st.st_uid != owner || (st.st_mode \& 0022)/st.st_uid != owner || false/' "$source";;
   hidden-collision) sed -i 's/throw std::runtime_error("charger_default_target_collision");/return true;/' "$source";;
  esac
  cmp -s "$source" "$root/src/boot/offline/target.hpp" && exit 1
  "$compiler" -std=c++17 -O1 -g -UNDEBUG -Wall -Wextra -Werror "$work/mutant/tests/offline-target.cpp" -o "$work/mutant-test"
  status=0
  timeout -k 1s 20s "$work/mutant-test" > "$work/mutant.log" 2>&1 || status=$?
  [[ $status == 134 ]]
  grep -Eqi 'assert|assertion' "$work/mutant.log"
  printf 'Required offline target mutant refused:%s/%s.\n' "$compiler" "$mutant"
 done
done
# Confirm the real original systemctl rejects the old argument without any
# request to PID1; help parsing alone must reject it. Normal switch-root syntax
# is also checked only through help, never executed.
status=0
LC_ALL=C systemctl --unit=uke-offline-charge.target --help > "$work/original.txt" 2>&1 || status=$?
[[ $status == 1 ]]
grep -Fq "unrecognized option '--unit'" "$work/original.txt"
LC_ALL=C systemctl --no-block switch-root --help > "$work/fixed.txt"
grep -Fq 'switch-root' "$work/fixed.txt"
printf 'Original systemctl option refusal and supported normal handoff syntax verified without PID1 operation.\n'
