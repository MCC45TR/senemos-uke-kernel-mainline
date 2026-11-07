#!/usr/bin/env bash
# Exact additive control delta; retained checks consume the authenticated parent.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared cumulative source}")
profile=$kernel/native-profile
actual=$kernel/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c
before=$kernel/native-generated/runtime-before-enable-readback.c
printf '%s  %s\n' \
 e839faa9f2f08a1880d8c94ed6c1ba77b5e70c1731f1a7724acba0b5b5eccf2b "$actual" \
 2db81985157213fbe61d9d58bd997784264fcee05d34f96f9d4fe1474e92205f "$before" | sha256sum -c --strict --quiet -
[[ -f $actual && ! -L $actual && -f $before && ! -L $before ]]
jq -e '.speaker_enable_readback_layer==1 and .speaker_enable_readback_read_only and
 .speaker_enable_readback_alignment_fix_layer==1 and .speaker_enable_readback_alignment_padding_ignored and
 .speaker_enable_readback_privileged and .speaker_enable_readback_owner_and_generation and
 .speaker_gain_ceiling==223 and (.speaker_physical_protection_qualified|not) and
 (.physical_acceptance|not)' "$profile/source-composition.json" >/dev/null
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
install -Dm644 "$actual" "$work/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
git -C "$work" apply --reverse --check --whitespace=error "$profile/src/audio/0026-fs19xx-enable-readback-control.patch"
git -C "$work" apply --reverse --whitespace=error "$profile/src/audio/0026-fs19xx-enable-readback-control.patch"
cmp "$before" "$work/sound/soc/qcom/qdsp6/uke-fs19xx-runtime.c"
printf '%s\n' "$before"
