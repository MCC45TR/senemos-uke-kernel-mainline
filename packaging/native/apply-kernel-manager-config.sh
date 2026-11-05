#!/usr/bin/env bash
# Source/config only. Never run on the target or select/install a kernel.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?prepared cumulative kernel}")
input=$(realpath "${2:?complete baseline config}")
output=$(realpath -m "${3:?new candidate config}")
fragment=$(realpath "${4:?reviewed manager fragment}")
[[ -f $kernel/scripts/config && -f $input && ! -L $input && -f $fragment && ! -L $fragment ]]
[[ $input != "$output" && ! -e $output && ! -L $output ]]
mkdir -p "$(dirname "$output")"
install -m644 "$input" "$output"
while IFS= read -r line; do
 if [[ $line =~ ^CONFIG_([A-Z0-9_]+)=(y|m)$ ]]; then
  symbol=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
  [[ $value != y ]] || bash "$kernel/scripts/config" --file "$output" --enable "$symbol"
  [[ $value != m ]] || bash "$kernel/scripts/config" --file "$output" --module "$symbol"
 elif [[ $line =~ ^\#\ CONFIG_([A-Z0-9_]+)\ is\ not\ set$ ]]; then
  bash "$kernel/scripts/config" --file "$output" --disable "${BASH_REMATCH[1]}"
 elif [[ -n $line && $line != \#* ]]; then
  printf 'Unsupported fragment line: %s\n' "$line" >&2; exit 1
 fi
done < "$fragment"
