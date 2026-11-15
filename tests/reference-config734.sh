#!/usr/bin/bash
# Data-only checks against independently resolved signed native observations.
set -Eeuo pipefail
[[ $# == 1 ]]
candidate=$(realpath "$1")
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
parent=$owner/tests/fixtures/reference733-before734.config
printf '%s  %s\n' 1385a82ce024620768768eba9511d8fb755bd72904015d8a4043559308f559f1 "$parent" | sha256sum -c --strict --quiet -
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
bash "$owner/tests/project-reference734.sh" "$candidate" "$work/projected.config"
effective(){ awk '/^CONFIG_[A-Z0-9_]+=/ || /^# CONFIG_[A-Z0-9_]+ is not set$/' "$1" | LC_ALL=C sort; }
effective "$parent" > "$work/parent.effective"
effective "$work/projected.config" > "$work/projected.effective"
cmp "$work/parent.effective" "$work/projected.effective"
bash "$owner/tests/cdsp-pogo-toolchain-contract.sh" "$candidate"
bash "$owner/tests/cdsp-pogo-config-contract.sh" "$parent"
for mutant in missing-exit disabled-exit duplicate-exit intel-present functional;do
 case $mutant in
 missing-exit) sed '/^CONFIG_HAVE_EXIT_THREAD=y$/d' "$candidate" > "$work/mutant.config";;
 disabled-exit) sed 's/^CONFIG_HAVE_EXIT_THREAD=y$/# CONFIG_HAVE_EXIT_THREAD is not set/' "$candidate" > "$work/mutant.config";;
 duplicate-exit) cat "$candidate" > "$work/mutant.config";printf 'CONFIG_HAVE_EXIT_THREAD=y\n' >> "$work/mutant.config";;
 intel-present) cat "$candidate" > "$work/mutant.config";printf '# CONFIG_INTEL_SSEI is not set\n' >> "$work/mutant.config";;
 functional) sed 's/^CONFIG_NR_CPUS=.*/CONFIG_NR_CPUS=999/' "$candidate" > "$work/mutant.config";;
 esac
 ! cmp -s "$candidate" "$work/mutant.config"
 if bash "$owner/tests/cdsp-pogo-config-contract.sh" "$work/mutant.config" > "$work/refused.log" 2>&1;then
  printf 'Historical734 refusal failed:%s\n' "$mutant" >&2;exit 1
 fi
done
printf 'Historical734 config: exact two-upstream-setting projection equals independent733 reference; original digest/compiler/five refusals and five additional controls passed. Actual config unchanged.\n'
