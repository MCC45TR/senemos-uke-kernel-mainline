#!/usr/bin/env bash
# Actual typed read implementation with a bounded host-only SCMI transport.
set -Eeuo pipefail
source_file=${1:?Pass qcom-memlat.c}
header=${2:?Pass scmi_qcom_memlat.h}
shmem_file=${3:-}
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source/drivers/firmware/arm_scmi/vendors/qcom" "$work/include/linux"
cp "$source_file" "$work/source/drivers/firmware/arm_scmi/vendors/qcom/qcom-memlat.c"
cp "$header" "$work/include/linux/scmi_qcom_memlat.h"
cat > "$work/include/linux/types.h" <<'C'
#include <stdint.h>
typedef uint8_t u8;
typedef uint32_t u32;
typedef uint64_t u64;
typedef uint32_t __le32;
typedef uint64_t __le64;
C
cat > "$work/source/drivers/firmware/arm_scmi/protocols.h" <<'C'
#include <assert.h>
#include <endian.h>
#include <errno.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#undef static_assert
#define static_assert(expr, ...) _Static_assert(expr, "")
#define lower_32_bits(x) ((u32)(x))
#define upper_32_bits(x) ((u32)((x) >> 32))
#define cpu_to_le32(x) htole32(x)
#define le32_to_cpu(x) le32toh(x)
#define le64_to_cpu(x) le64toh(x)
struct scmi_xfer { struct { int status; } hdr; struct { void *buf; size_t len; } tx, rx; };
struct scmi_xfer_ops {
    int (*xfer_get_init)(const struct scmi_protocol_handle *, u8, size_t, size_t, struct scmi_xfer **);
    int (*do_xfer)(const struct scmi_protocol_handle *, struct scmi_xfer *);
    void (*xfer_put)(const struct scmi_protocol_handle *, struct scmi_xfer *);
};
struct scmi_protocol_handle { const struct scmi_xfer_ops *xops; };
C
cat > "$work/check.c" <<'C'
#include "source/drivers/firmware/arm_scmi/vendors/qcom/qcom-memlat.c"
C
if [[ -n $shmem_file ]]; then
    cat >> "$work/check.c" <<'C'
#define CPUCP_TEST_NATIVE_SHMEM 1
#define __iomem
#define BIT(n) (1U << (n))
#define min_t(type, a, b) ((type)(a) < (type)(b) ? (type)(a) : (type)(b))
typedef void (*shmem_copy_fromio_t)(void *, const void *, size_t);
static u32 ioread32(const void *address) { u32 value; memcpy(&value, address, 4); return le32toh(value); }
static void copy_fromio(void *to, const void *from, size_t count) { memcpy(to, from, count); }
static bool native_transport;
C
    awk '/^struct scmi_shared_mem \{/ { emit=1 } emit { print } emit && /^};/ { exit }' "$shmem_file" >> "$work/check.c"
    awk '/^static void shmem_fetch_response\(/ { emit=1 } emit { print } emit && /^}/ { exit }' "$shmem_file" >> "$work/check.c"
fi
cat >> "$work/check.c" <<'C'
static unsigned char tx[104], rx[104], captured[104];
static struct scmi_xfer transfer;
static size_t tx_size, rx_size, reply_length;
static unsigned int gets, sends, put_calls;
static int allocation_error, transfer_error;
static int get(const struct scmi_protocol_handle *ph, u8 id, size_t in, size_t out, struct scmi_xfer **result) {
    (void)ph; gets++; assert(id == 0x11 && in <= sizeof(tx) && out <= sizeof(rx));
    tx_size = in; rx_size = out;
    if (allocation_error) return allocation_error;
    memset(tx, 0xa5, sizeof(tx)); memset(rx, 0, sizeof(rx));
    transfer.tx.buf = tx; transfer.tx.len = in;
    transfer.rx.buf = rx; transfer.rx.len = out; *result = &transfer;
    return 0;
}
static int send(const struct scmi_protocol_handle *ph, struct scmi_xfer *t) {
    (void)ph; assert(t == &transfer); sends++;
    memcpy(captured, tx, tx_size);
    for (unsigned int i = 0; i < sizeof(rx); i++) rx[i] = i + 1;
#ifdef CPUCP_TEST_NATIVE_SHMEM
    if (native_transport) {
        _Alignas(8) unsigned char area[sizeof(struct scmi_shared_mem) + 108] = {0};
        struct scmi_shared_mem *shared = (void *)area;
        shared->length = htole32(reply_length > UINT32_MAX - 8 ? UINT32_MAX : reply_length + 8);
        for (unsigned int i = 0; i < 104; i++) shared->msg_payload[i + 4] = i + 1;
        shmem_fetch_response(shared, t, copy_fromio);
    } else
#endif
        t->rx.len = reply_length;
    return transfer_error;
}
static void put(const struct scmi_protocol_handle *ph, struct scmi_xfer *t) {
    (void)ph; assert(t == &transfer); put_calls++;
}
static void reset(size_t length) {
    gets = sends = put_calls = 0; allocation_error = transfer_error = 0;
    reply_length = length; tx_size = rx_size = 0; memset(captured, 0xa5, sizeof(captured));
}
static int run(const struct scmi_protocol_handle *ph, unsigned int mode, u64 *output) {
    if (!mode) return scmi_qcom_memlat_read_ops.timestamp_raw(ph, output);
    u32 value = (u32)*output;
    int ret = mode == 1 ? scmi_qcom_memlat_read_ops.current_raw(ph, 0x11223344, 0x55667788, &value) :
        scmi_qcom_memlat_read_ops.adaptive_raw(ph, 0x11223344, &value);
    *output = value; return ret;
}
int main(void) {
    const struct scmi_xfer_ops ops = {get, send, put};
    const struct scmi_protocol_handle ph = {&ops}, no_ops = {NULL};
    unsigned char expected[28] = {0, 0, 0, 0, 0x54, 0x41, 0x4c, 0x4d, 0x45, 0x4d, 0, 0};
    u64 value;
    reset(4);
    assert(scmi_qcom_memlat_read_ops.timestamp_raw(NULL, &value) == -EINVAL);
    assert(scmi_qcom_memlat_read_ops.current_raw(&no_ops, 0, 0, (u32 *)&value) == -EINVAL);
    assert(scmi_qcom_memlat_read_ops.timestamp_raw(&ph, NULL) == -EINVAL);
    assert(scmi_qcom_memlat_read_ops.current_raw(&ph, 0, 0, NULL) == -EINVAL);
    assert(scmi_qcom_memlat_read_ops.adaptive_raw(&ph, 0, NULL) == -EINVAL);
    assert(qcom_memlat_read(&ph, 0xffffffff, 0, 0, &value) == -EINVAL && !gets);
    assert(qcom_memlat_read(&ph, 35, 0, 0, NULL) == -EINVAL && !gets);
    for (unsigned int path = 0; path < 2; path++) {
#ifdef CPUCP_TEST_NATIVE_SHMEM
    native_transport = path;
#else
    if (path) break;
#endif
    for (unsigned int mode = 0; mode < 3; mode++) {
        size_t length = mode ? 4 : 8;
        reset(length); value = 0;
        assert(run(&ph, mode, &value) == 0 && gets == 1 && sends == 1 && put_calls == 1);
        assert(value == (mode ? UINT64_C(0x04030201) : UINT64_C(0x0807060504030201)));
        assert(tx_size == (mode ? 28 : 16) && rx_size >= length && rx_size <= length + 4);
        memset(expected + 12, 0, sizeof(expected) - 12);
        expected[12] = mode == 0 ? 38 : mode == 1 ? 35 : 22;
        if (mode) {
            const unsigned char hardware[] = {0x44, 0x33, 0x22, 0x11};
            const unsigned char monitor[] = {0x88, 0x77, 0x66, 0x55};
            memcpy(expected + 16, hardware, sizeof(hardware));
            if (mode == 1) memcpy(expected + 20, monitor, sizeof(monitor));
        }
        assert(!memcmp(captured, expected, tx_size));
        for (size_t i = tx_size; i < sizeof(tx); i++) assert(tx[i] == 0xa5);
        const int allocation_errors[] = {-ENOMEM, -ERANGE, -EBUSY};
        for (unsigned int i = 0; i < sizeof(allocation_errors) / sizeof(allocation_errors[0]); i++) {
            reset(length); allocation_error = allocation_errors[i]; value = 0xdeadbeef;
            assert(run(&ph, mode, &value) == allocation_errors[i] && value == 0xdeadbeef && gets == 1 && !sends && !put_calls);
        }
        reset(length); transfer_error = -EREMOTEIO; value = 0xdeadbeef;
        assert(run(&ph, mode, &value) == -EREMOTEIO && value == 0xdeadbeef && sends == 1 && put_calls == 1);
        const size_t wrong_lengths[] = {0, 1, 3, 5, 7, 9, 104, SIZE_MAX};
        for (unsigned int i = 0; i < sizeof(wrong_lengths) / sizeof(wrong_lengths[0]); i++) {
            reset(wrong_lengths[i]); value = 0xdeadbeef;
            assert(run(&ph, mode, &value) == -EPROTO && value == 0xdeadbeef && sends == 1 && put_calls == 1);
            reset(wrong_lengths[i]); transfer_error = -ETIMEDOUT; value = 0xdeadbeef;
            assert(run(&ph, mode, &value) == -ETIMEDOUT && value == 0xdeadbeef && put_calls == 1);
        }
    }
    }
#ifdef CPUCP_TEST_NATIVE_SHMEM
    puts("Actual SCMI shared-memory clipping path: short/long replies rejected before output copy");
#endif
    puts("Actual MEMLAT reads: exact LE envelopes, zero fields, bounded sizes, unchanged failed outputs and transfer cleanup passed");
}
C
"${CC:-gcc}" -std=gnu11 -O2 -Wall -Wextra -Werror ${CPUCP_TEST_CFLAGS:-} \
    -I "$work/include" "$work/check.c" -o "$work/check"
"$work/check"
