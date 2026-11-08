#!/usr/bin/bash
# COPR only: pinned Fedora schema tools and actual early-DT producers.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
umask 077
profile=$(realpath "${1:?Source profile}")
schema=$(realpath "${2:?Patched xiaomi,uke-ssc-sensors schema}")
work=$(mktemp -d)
cleanup() {
  result=$?
  if ((result)); then
    while IFS= read -r -d '' log; do
      if test -s "$log"; then
        printf 'Dual-light schema diagnostic: %s\n' "${log#"$work"/}" >&2
        sed -n '1,120p' "$log" >&2
      fi
    done < <(find "$work" -type f -name '*.log' -print0)
  fi
  find "$work" -depth -delete
  exit "$result"
}
trap cleanup EXIT
[[ $(rpm -q --qf '%{VERSION}-%{RELEASE}' dt-schema) == 2026.09-1.fc46 ]]
dt-doc-validate "$schema" > "$work/schema.log" 2>&1
test ! -s "$work/schema.log"
positive=0
for cxx in g++ clang++; do
  for sanitize in 0 1; do
    flags=(-std=c++17 -O1 -g -UNDEBUG -Wall -Wextra -Werror -Wno-unused-function -fno-omit-frame-pointer)
    [[ $sanitize == 0 ]] || flags+=(-fsanitize=address,undefined -fno-sanitize-recover=all)
    "$cxx" "${flags[@]}" -I"$profile/src/boot" "$profile/tests/ssc-dual-light-schema.cpp" -lfdt -o "$work/emitter"
    directory=$work/$cxx-$sanitize
    mkdir -m700 "$directory"
    ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1 "$work/emitter" "$directory"
    for kind in unlinked linked; do
      dt-validate -s "$schema" -l xiaomi,uke-ssc-sensors "$directory/$kind.dtb" > "$directory/$kind.log" 2>&1
      test ! -s "$directory/$kind.log"
      [[ $(stat -c %a "$directory/$kind.dtb") == 600 ]]
      positive=$((positive+1))
    done
    [[ $(fdtget -t x "$directory/linked.dtb" /firmware/ssc-sensors lid-switch) == "$(fdtget -t x "$directory/linked.dtb" /hall-lid phandle)" ]]
    printf 'Actual dual-light schema producer mode passed:%s/sanitize%s.\n' "$cxx" "$sanitize"
  done
done
base=$work/g++-0/linked.dtb
for mode in missing-remoteproc lid-wide lid-string child-type child-label extra-property short-matrix; do
  cp "$base" "$work/$mode.dtb"
  case $mode in
    missing-remoteproc) fdtput -d "$work/$mode.dtb" /firmware/ssc-sensors remoteproc;;
    lid-wide) fdtput -t u "$work/$mode.dtb" /firmware/ssc-sensors lid-switch 23 24;;
    lid-string) fdtput -t s "$work/$mode.dtb" /firmware/ssc-sensors lid-switch unrelated;;
    child-type) fdtput -t s "$work/$mode.dtb" /firmware/ssc-sensors/front-light qcom,ssc-datatype unrelated;;
    child-label) fdtput -d "$work/$mode.dtb" /firmware/ssc-sensors/front-light label;;
    extra-property) fdtput -t u "$work/$mode.dtb" /firmware/ssc-sensors unreviewed 1;;
    short-matrix) fdtput -t s "$work/$mode.dtb" /firmware/ssc-sensors/accelerometer mount-matrix 1 0 0;;
  esac
  dt-validate -s "$schema" -l xiaomi,uke-ssc-sensors "$work/$mode.dtb" > "$work/$mode.log" 2>&1 || true
  grep -q 'xiaomi,uke-ssc-sensors' "$work/$mode.log"
  printf 'Actual dual-light schema negative refused:%s.\n' "$mode"
done
[[ $positive == 8 ]]
printf 'Actual dual-light binding: schema document, eight real-producer synthetic DTBs and seven negative schema controls passed; runtime board/physical acceptance separate.\n'
