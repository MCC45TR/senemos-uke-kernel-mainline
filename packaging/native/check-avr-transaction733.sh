#!/usr/bin/bash
# Production callbacks and objects, without rerunning inherited source suites.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
kernel=$(realpath "${1:?Prepared kernel}")
out=$(realpath "${2:?Native output}")
phase=${3:?source, objects or linked}
[[ $phase == source || $phase == objects || $phase == linked ]]
profile=$kernel/native-profile
git -C "$kernel" apply --reverse --check "$profile/src/display/0075-o82-avr-retime-rollback.patch"
grep -F 'c->ops.get_avr_period = dpu_hw_intf_get_avr_period;' "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_hw_intf.c"
grep -F 'c->ops.set_avr_period = dpu_hw_intf_set_avr_period;' "$kernel/drivers/gpu/drm/msm/disp/dpu1/dpu_hw_intf.c"
jq -e '.avr_transaction_layer==1 and .avr_transaction_sourcecheck_required and .avr_transaction_keeps_atomic_quarantine and (.avr_transaction_full_modeset_rollback|not) and (.avr_transaction_physical_accepted|not) and .speaker_gain_ceiling==223' "$profile/source-composition.json" >/dev/null
[[ $phase != source ]] || exit 0
for part in dpu_encoder dpu_hw_intf; do
 object=$out/drivers/gpu/drm/msm/disp/dpu1/$part.o
 llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
 llvm-nm "$object" > "$out/avr-transaction-$part.symbols"
done
grep -Eq ' [Tt] dpu_encoder_uke_avr_retime$' "$out/avr-transaction-dpu_encoder.symbols"
for symbol in dpu_hw_intf_get_avr_period dpu_hw_intf_set_avr_period; do
 grep -Eq " [Tt] $symbol$" "$out/avr-transaction-dpu_hw_intf.symbols"
done
if [[ $phase == linked ]]; then
 module=$out/drivers/gpu/drm/msm/msm.ko
 llvm-nm "$module" > "$out/avr-transaction-msm.symbols"
 for symbol in dpu_encoder_uke_avr_retime dpu_hw_intf_get_avr_period dpu_hw_intf_set_avr_period; do
  grep -Eq " [Tt] $symbol$" "$out/avr-transaction-msm.symbols"
 done
fi
printf 'Actual cumulative dual-INTF AVR transaction and MMIO objects passed:%s; DSI recovery and physical acceptance separate.\n' "$phase"
