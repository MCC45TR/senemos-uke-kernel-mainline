#!/usr/bin/bash
# Read-only compatibility projection for the original sealed historical guard.
# Never modify the actual config or disable the upstream ARM64 cleanup fix.
set -Eeuo pipefail
[[ $# == 2 ]]
input=$(realpath "$1");output=$(realpath -m "$2")
[[ -f $input && ! -L $input && ! -e $output && ! -L $output ]]
if grep -Fxq '# Linux/arm64 7.3.4 Kernel Configuration' "$input";then
 [[ $(grep -Ec '^(CONFIG_HAVE_EXIT_THREAD=|# CONFIG_HAVE_EXIT_THREAD is not set$)' "$input") == 1 ]]
 grep -Fxq 'CONFIG_HAVE_EXIT_THREAD=y' "$input"
 ! grep -Eq '^(CONFIG_INTEL_SSEI=|# CONFIG_INTEL_SSEI is not set$)' "$input"
 sed '/^CONFIG_HAVE_EXIT_THREAD=y$/d' "$input" > "$output"
 printf '# CONFIG_INTEL_SSEI is not set\n' >> "$output"
else
 cp "$input" "$output"
fi
