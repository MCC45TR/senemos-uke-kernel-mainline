#!/usr/bin/env bash
# Host-only check of the actual Uke hci_qca power table.
set -Eeuo pipefail
file=${1:?Pass the prepared hci_qca.c}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
{
    cat <<'C'
#include <assert.h>
#include <string.h>
#define __maybe_unused
#define QCA_CAP_WIDEBAND_SPEECH 1
#define QCA_CAP_VALID_LE_STATES 2
enum { QCA_WCN6750 };
struct qca_vreg { const char *name; unsigned int load_uA; };
struct qca_device_data { int soc_type; struct qca_vreg *vregs; unsigned int num_vregs, capabilities; };
C
    sed -n '/^static const struct qca_device_data qca_soc_data_uke_wcn6750/,/^};/p' "$file"
    cat <<'C'
int main(void) {
    const struct qca_device_data *data = &qca_soc_data_uke_wcn6750;
    const char *names[] = {"vddio", "vddaon", "vddbtcxmx", "vddrfacmn", "vddrfa0p8", "vddrfa1p7", "vddrfa1p2", "vddrfa2p2"};
    assert(data->soc_type == QCA_WCN6750 && data->num_vregs == 8);
    for (unsigned int i = 0; i < data->num_vregs; i++) {
        assert(!strcmp(data->vregs[i].name, names[i]));
        assert(data->vregs[i].load_uA == 0);
    }
}
C
} > "$work/check.c"
${CC:-cc} -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
grep -F '"xiaomi,uke-wcn6750-bt", .data = &qca_soc_data_uke_wcn6750' "$file" >/dev/null
printf '%s\n' 'Uke Bluetooth: exact eight OEM rails, zero load votes and dedicated OF match passed'
