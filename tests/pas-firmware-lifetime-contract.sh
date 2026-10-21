#!/usr/bin/env bash
# Actual PAS load/unprepare with host-only firmware ownership fixtures.
set -Eeuo pipefail
source_file=${1:?Pass the prepared qcom_q6v5_pas.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstring>
#include <cstdint>
struct firmware { unsigned int serial; };
struct device {};
struct context {};
struct qcom_pas {
    device *dev;
    const struct firmware *firmware = nullptr, *dtb_firmware = nullptr;
    int lite_pas_id = 0, lite_dtb_pas_id = 0, dtb_pas_id = 0;
    const char *dtb_firmware_name = "cdsp_dtb.mdt";
    context *pas_ctx = nullptr, *dtb_pas_ctx = nullptr;
    void *dtb_mem_region = nullptr;
    uintptr_t dtb_mem_reloc = 0;
};
struct rproc { qcom_pas *priv; const char *firmware = "cdsp.mdt"; };
static unsigned int live, serial, releases, requests, loads, metadata_releases;
static int request_error, load_error;
template<class... T> void dev_err(device *, const char *, T...) {}
static int qcom_scm_pas_shutdown(int) { assert(false); return 0; }
static void qcom_scm_pas_metadata_release(context *) { ++metadata_releases; }
static int request_firmware(const firmware **out, const char *name, device *) {
    ++requests; assert(!std::strcmp(name,"cdsp_dtb.mdt")); *out=nullptr;
    if (request_error) return request_error;
    *out=new firmware{++serial}; ++live; return 0;
}
static void release_firmware(const firmware *fw) {
    if (!fw) return;
    assert(live==1 && fw->serial==serial);
    delete fw; --live; ++releases;
}
static int qcom_mdt_pas_load(context *, const firmware *fw, const char *, void *, uintptr_t *) {
    assert(live==1 && fw && fw->serial==serial); ++loads; return load_error;
}
CPP
awk '/^static int qcom_pas_(unprepare|load)\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$source_file" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
int main() {
    device dev;
    qcom_pas pas{&dev}; rproc remote{&pas};
    const struct firmware main_fw{0};
    assert(qcom_pas_load(&remote,&main_fw)==0 && !requests && !loads && !live);
    assert(qcom_pas_unprepare(&remote)==0 && !releases);
    pas.dtb_pas_id=0x25;
    request_error=-EIO;
    assert(qcom_pas_load(&remote,&main_fw)==-EIO && !live);
    assert(qcom_pas_unprepare(&remote)==0 && !releases);
    request_error=0; load_error=-EINVAL;
    assert(qcom_pas_load(&remote,&main_fw)==-EINVAL && !live && releases==1);
    assert(qcom_pas_unprepare(&remote)==0 && releases==1);
    load_error=0;
    for (int i=0;i<128;++i) {
        assert(qcom_pas_load(&remote,&main_fw)==0 && !live);
        assert(qcom_pas_unprepare(&remote)==0 && !live);
        assert(qcom_pas_unprepare(&remote)==0 && !live);
    }
    // Crash recovery reloads segments without the device-unprepare callback.
    for (int i=0;i<128;++i)
        assert(qcom_pas_load(&remote,&main_fw)==0 && !live);
    assert(releases==257 && pas.firmware==&main_fw && main_fw.serial==0);
    assert(metadata_releases==518);
}
CPP
flags=(-std=c++20 -O2 -Wall -Wextra -Werror)
if [[ ${SANITIZE:-0} == 1 ]]; then
    flags+=(-O1 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
fi
"${CXX:-g++}" "${flags[@]}" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual PAS DTB firmware: legacy, request/load failures, 128 normal and recovery cycles, idempotent cleanup and borrowed main image passed\n'
