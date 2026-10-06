#!/usr/bin/env bash
# Host-only numeric comparison against the exact OEM source, never a tablet test.
set -Eeuo pipefail
[[ $# == 3 ]] || { echo 'Usage: check-ufs-tables.sh OEM_SOURCE KERNEL_SOURCE OUTPUT_DIR' >&2; exit 2; }
oem=$(realpath "$1") kernel=$(realpath "$2") out=$(realpath -m "$3")
mkdir -p "$out"
header=$oem/drivers/phy/qualcomm/phy-qcom-ufs-qmp-v4-pineapple.h
driver=$kernel/drivers/phy/qualcomm/phy-qcom-qmp-ufs.c
[[ -f $header && -f $driver ]]
grep -F '"qcom,ufs-phy-qmp-v4-cliffs"' "$oem/drivers/phy/qualcomm/phy-qcom-ufs-qmp-v4-pineapple.c" >/dev/null
{
    cat <<'CPP'
#include <cstdint>
#include <iostream>
#include <map>
#include <stdexcept>
struct Pair { unsigned offset, value; };
#define UFS_QCOM_PHY_CAL_ENTRY(reg, val) {reg, val}
#define QMP_PHY_INIT_CFG(reg, val) {reg, val}
CPP
    awk '/^#define / {print}' "$header"
    awk '/^static struct ufs_qcom_phy_calibration / {active=1; sub(/struct ufs_qcom_phy_calibration/, "Pair")} active {print} active && /^};/ {active=0}' "$header"
    for registers in phy-qcom-qmp-qserdes-com-v6.h phy-qcom-qmp-qserdes-txrx-ufs-v6.h phy-qcom-qmp-pcs-ufs-v6.h; do
        printf '#include "%s/drivers/phy/qualcomm/%s"\n' "$kernel" "$registers"
    done
    awk '/^static const struct qmp_phy_init_tbl sm7675_/ {active=1; sub(/struct qmp_phy_init_tbl/, "Pair")} active {print} active && /^};/ {active=0}' "$driver"
    cat <<'CPP'
using Registers = std::map<unsigned, unsigned>;
template<std::size_t N> void apply_table(Registers& r, const Pair (&table)[N], unsigned base=0) {
    for (auto p : table) r[base + p.offset] = p.value;
}
int main() {
    for (unsigned gear : {4u, 5u}) for (bool rate_b : {false, true}) {
        Registers expected, actual;
        apply_table(expected, phy_cal_table_rate_A_g5);
        if (gear == 4) apply_table(expected, phy_cal_table_rate_A_g4);
        apply_table(expected, phy_cal_table_2nd_lane);
        if (rate_b) apply_table(expected, phy_cal_table_rate_B);
        // Upstream's power-on helper owns this register rather than its tables.
        expected.erase(UFS_PHY_POWER_DOWN_CONTROL);
        apply_table(actual, sm7675_ufsphy_serdes);
        for (unsigned lane : {0u, 1u}) {
            apply_table(actual, sm7675_ufsphy_tx, 0x1000 + lane * 0x800);
            apply_table(actual, sm7675_ufsphy_rx, 0x1200 + lane * 0x800);
        }
        apply_table(actual, sm7675_ufsphy_pcs, 0x400);
        if (gear == 4) apply_table(actual, sm7675_ufsphy_g4_pcs, 0x400);
        if (rate_b) apply_table(actual, sm7675_ufsphy_hs_b_pcs, 0x400);
        if (actual != expected) throw std::runtime_error("OEM register/value mismatch");
        actual.begin()->second ^= 1;
        if (actual == expected) throw std::runtime_error("Mutation was not detected");
        std::cout << "Gear " << gear << " rate " << (rate_b ? 'B' : 'A')
                  << ": " << expected.size() << " effective OEM addresses match\n";
    }
}
CPP
} > "$out/register-comparison.cpp"
"${CXX:-c++}" -std=c++17 -Wall -Wextra -Werror -O1 "$out/register-comparison.cpp" -o "$out/register-comparison"
"$out/register-comparison" > "$out/register-comparison.txt"
cat "$out/register-comparison.txt"
