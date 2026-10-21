#!/usr/bin/env bash
# Exercise the actual PAS stop callback; no SCM calls or device writes.
set -Eeuo pipefail
source_file=${1:?Pass the prepared qcom_q6v5_pas.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdint>
#define QCOM_PAS_DECRYPT_SHUTDOWN_DELAY_MS 100
struct device {};
struct qcom_q6v5 {};
struct qcom_pas {
    device *dev;
    struct qcom_q6v5 q6v5;
    void *sysmon = nullptr;
    int pas_id = 18, dtb_pas_id = 0;
    bool decrypt_shutdown = false;
    bool pas_shutdown_done = false, stop_resources_released = false;
    uintptr_t mem_phys = 0x1000, dtb_mem_phys = 0x2000;
    unsigned int mem_size = 16, dtb_mem_size = 8;
    unsigned int smem_host_id = 5;
};
struct rproc { qcom_pas *priv; };
static bool primary_running, dtb_running, main_mapped, dtb_mapped;
static int primary_calls, dtb_calls, stop_requests, unmaps, unprepares, handovers, smem_calls;
static int primary_errors_left, primary_error, dtb_error, smem_error, request_error, handover;
static unsigned int sleeps;
template<class... T> void dev_err(device *, const char *, T...) {}
static void msleep(unsigned int ms) { assert(ms==100); ++sleeps; }
static int qcom_q6v5_request_stop(qcom_q6v5 *, void *) { ++stop_requests; return request_error; }
static int qcom_scm_pas_shutdown(int id) {
    if (id==18) {
        ++primary_calls; assert(primary_running);
        if (primary_errors_left) { --primary_errors_left; return primary_error; }
        primary_running=false; return 0;
    }
    assert(id==0x25 && !primary_running && dtb_running);
    ++dtb_calls;
    if (dtb_error) return dtb_error;
    dtb_running=false; return 0;
}
static void qcom_pas_unmap_carveout(rproc *, uintptr_t phys, unsigned int size) {
    assert(!primary_running && !dtb_running); ++unmaps;
    if (phys==0x1000) { assert(size==16 && main_mapped); main_mapped=false; }
    else { assert(phys==0x2000 && size==8 && dtb_mapped); dtb_mapped=false; }
}
static int qcom_q6v5_unprepare(qcom_q6v5 *) {
    assert(!primary_running && !dtb_running && !main_mapped && !dtb_mapped);
    ++unprepares; assert(unprepares==1); return handover;
}
static void qcom_pas_handover(qcom_q6v5 *) { ++handovers; assert(unprepares==1 && handovers==1); }
static int qcom_smem_bust_hwspin_lock_by_host(unsigned int host) {
    assert(host==5 && !primary_running && !dtb_running && unprepares==1);
    ++smem_calls; return smem_error;
}
CPP
awk '/^static int qcom_pas_(shutdown_poll_decrypt|stop)\(/ {emit=1} emit {print} emit && /^}/ {emit=0}' "$source_file" >> "$work/check.cpp"
for function in start attach; do
    printf 'static void reset_%s(qcom_pas *pas) {\n(void)pas;\n' "$function" >> "$work/check.cpp"
    awk -v fn="qcom_pas_$function" '
        $0 ~ "^static int " fn "\\(" {body=1}
        body && /^}/ {exit}
        body && /pas->(pas_shutdown_done|stop_resources_released) = false;/ {print}
    ' "$source_file" >> "$work/check.cpp"
    printf '}\n' >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
static void fixture(qcom_pas &pas, bool dtb) {
    pas.dtb_pas_id=dtb?0x25:0;
    pas.pas_shutdown_done=pas.stop_resources_released=false;
    pas.decrypt_shutdown=false; pas.smem_host_id=5;
    primary_running=main_mapped=true; dtb_running=dtb_mapped=dtb;
    primary_calls=dtb_calls=stop_requests=unmaps=unprepares=handovers=smem_calls=0;
    primary_errors_left=primary_error=dtb_error=smem_error=request_error=handover=0; sleeps=0;
}
static void retained() { assert(main_mapped && dtb_mapped && !unmaps && !unprepares && !handovers && !smem_calls); }
int main() {
    device dev; qcom_pas pas{}; pas.dev=&dev; rproc remote{&pas};
    fixture(pas,true); primary_errors_left=1; primary_error=-EACCES;
    assert(qcom_pas_stop(&remote)==-EACCES); retained();
    assert(primary_running && dtb_running && !dtb_calls && !pas.pas_shutdown_done);
    assert(qcom_pas_stop(&remote)==0 && primary_calls==2 && stop_requests==2);
    for (bool dtb : {false,true}) for (int h : {0,1}) {
        fixture(pas,dtb); handover=h;
        assert(qcom_pas_stop(&remote)==0);
        assert(primary_calls==1 && dtb_calls==int(dtb) && stop_requests==1);
        assert(unmaps==1+int(dtb) && unprepares==1 && handovers==h && smem_calls==1);
        assert(pas.pas_shutdown_done && pas.stop_resources_released);
        assert(qcom_pas_stop(&remote)==0 && primary_calls==1 && unprepares==1);
        pas.pas_shutdown_done=pas.stop_resources_released=true; reset_start(&pas);
        assert(!pas.pas_shutdown_done && !pas.stop_resources_released);
        pas.pas_shutdown_done=pas.stop_resources_released=true; reset_attach(&pas);
        assert(!pas.pas_shutdown_done && !pas.stop_resources_released);
    }
    fixture(pas,true); request_error=-ETIMEDOUT;
    assert(qcom_pas_stop(&remote)==0 && primary_calls==1 && unmaps==2);
    fixture(pas,true); dtb_error=-EIO;
    assert(qcom_pas_stop(&remote)==-EIO); retained();
    assert(!primary_running && dtb_running && pas.pas_shutdown_done && !pas.stop_resources_released);
    dtb_error=0;
    assert(qcom_pas_stop(&remote)==0 && primary_calls==1 && stop_requests==1 && dtb_calls==2);
    fixture(pas,true); smem_error=-EBUSY;
    assert(qcom_pas_stop(&remote)==-EBUSY && pas.stop_resources_released);
    smem_error=0;
    assert(qcom_pas_stop(&remote)==0 && primary_calls==1 && dtb_calls==1 && unmaps==2 && unprepares==1 && smem_calls==2);
    fixture(pas,true); pas.decrypt_shutdown=true; primary_error=-EINVAL; primary_errors_left=50;
    assert(qcom_pas_stop(&remote)==0 && sleeps==50 && primary_calls==51);
    fixture(pas,true); pas.decrypt_shutdown=true; primary_error=-EINVAL; primary_errors_left=51;
    assert(qcom_pas_stop(&remote)==-EINVAL && sleeps==50 && primary_calls==51); retained();
    assert(qcom_pas_stop(&remote)==0 && primary_calls==52);
    fixture(pas,true); pas.decrypt_shutdown=true; primary_error=-EIO; primary_errors_left=2;
    assert(qcom_pas_stop(&remote)==-EIO && sleeps==1 && primary_calls==2); retained();
    fixture(pas,false); pas.smem_host_id=0;
    assert(qcom_pas_stop(&remote)==0 && !smem_calls && unmaps==1);
}
CPP
flags=(-std=c++20 -O2 -Wall -Wextra -Werror -include initializer_list)
if [[ ${SANITIZE:-0} == 1 ]]; then
    flags+=(-O1 -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
fi
"${CXX:-g++}" "${flags[@]}" "$work/check.cpp" -o "$work/check"
"$work/check"
printf 'Actual PAS stop: primary/DTB/SMEM failures, retained maps, ordered retry, decrypt bound, one-time cleanup and start/attach reset passed\n'
