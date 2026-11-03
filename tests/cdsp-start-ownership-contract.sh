#!/usr/bin/env bash
# COPR-only execution of the actual CDSP start, early-stop and cleanup functions.
set -Eeuo pipefail
source_file=${1:?Pass prepared qcom_q6v5_pas.c}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
cat > "$work/check.cpp" <<'CPP'
#include <cassert>
#include <cerrno>
#include <cstdint>
#include <cstddef>
#include <cstdio>
#define fallthrough [[fallthrough]]
#define RPROC_CRASHED 3
#define container_of(ptr,type,member) reinterpret_cast<type *>(reinterpret_cast<char *>(ptr)-offsetof(type,member))
using phys_addr_t=uint64_t;
struct device {};
struct firmware {};
struct clk { int refs=0; };
struct context { int id; };
struct qcom_q6v5 { bool prepared=false; };
CPP
awk '/^enum qcom_pas_stop_phase/ {p=1} p{print} p&&/^};/{p=0}' "$source_file" >> "$work/check.cpp"
cat >> "$work/check.cpp" <<'CPP'
struct qcom_pas {
    device *dev=nullptr; qcom_q6v5 q6v5; void *sysmon=nullptr;
    int pas_id=18,dtb_pas_id=37; bool decrypt_shutdown=false,cdsp=true;
    unsigned smem_host_id=5,proxy_regulator_level=384,proxy_regulator_count=3;
    int proxy_error=0; qcom_pas_stop_phase stop_phase=QCOM_PAS_STOP_IDLE;
    bool cdsp_primary_live=false,cdsp_dtb_live=false,cdsp_main_mapped=false,cdsp_dtb_mapped=false;
    bool cdsp_prepared=false,cdsp_xo_enabled=false,cdsp_aggre2_enabled=false,cdsp_start_failed=false;
    clk *xo=nullptr,*aggre2_clk=nullptr;
    void *cx_supply=nullptr,*px_supply=nullptr;
    context *pas_ctx=nullptr,*dtb_pas_ctx=nullptr;
    const struct firmware *firmware=nullptr;
    const char *info_name="cdsp";
    phys_addr_t mem_phys=0x99900000,dtb_mem_phys=0x9ad00000,mem_reloc=0;
    size_t mem_size=0x1400000,dtb_mem_size=0x80000;
};
struct rproc { qcom_pas *priv; const char *firmware="qcom/uke/cdsp/cdsp.mdt"; int state=2; };
static qcom_pas *active;
static int fault,step,primary_error,dtb_error,proxy_error;
static bool main_live,dtb_live,main_map,dtb_map,rails,handed,ready;
static unsigned unmaps,metadata,notices,primary_stops,dtb_stops;
static bool inject() { return step++==fault; }
template<class... T> void dev_err(device *,const char *,T...) {}
static int qcom_q6v5_prepare(qcom_q6v5 *q) { if(inject())return -EIO;q->prepared=true;return 0; }
static int qcom_q6v5_unprepare(qcom_q6v5 *q) { assert(q->prepared);q->prepared=false;return !handed; }
static int qcom_pas_proxy_enable(qcom_pas *) { rails=true;return inject()?-EIO:0; }
static int qcom_pas_proxy_disable(qcom_pas *p) { p->proxy_error=proxy_error;if(!proxy_error)rails=false;return proxy_error; }
static int clk_prepare_enable(clk *c) { if(inject())return -EIO;assert(c->refs==0);c->refs++;return 0; }
static void clk_disable_unprepare(clk *c) { assert(c->refs==1);c->refs--; }
static void regulator_disable(void *) { assert(false); }
static int qcom_pas_map_carveout(rproc *r,phys_addr_t base,size_t) {
    if(inject())return -EIO;
    bool &map=base==r->priv->mem_phys?main_map:dtb_map;assert(!map);map=true;return 0;
}
static void qcom_pas_unmap_carveout(rproc *r,phys_addr_t base,size_t) {
    assert(!main_live&&!dtb_live);
    bool &map=base==r->priv->mem_phys?main_map:dtb_map;assert(map);map=false;unmaps++;
}
static int qcom_pas_prepare_and_auth_reset(context *c) {
    (c->id==18?main_live:dtb_live)=true;return inject()?-EIO:0;
}
static int qcom_mdt_pas_load(context *,const firmware *,const char *,phys_addr_t *) { return inject()?-EIO:0; }
static void qcom_pil_info_store(const char *,phys_addr_t,size_t) {}
static unsigned msecs_to_jiffies(unsigned n) { return n; }
static int qcom_q6v5_wait_for_start(qcom_q6v5 *,unsigned) { if(inject())return -ETIMEDOUT;ready=true;return 0; }
static void qcom_pas_metadata_release(context *) { assert(ready||!active->cdsp_start_failed||(!main_live&&!dtb_live));metadata++; }
static int qcom_q6v5_request_stop(qcom_q6v5 *,void *) { assert(!active->cdsp_start_failed);return 0; }
static int qcom_pas_shutdown(int id) {
    if(id==18){assert(main_live);primary_stops++;if(primary_error)return primary_error;main_live=false;}
    else {assert(id==37&&dtb_live&&!main_live);dtb_stops++;if(dtb_error)return dtb_error;dtb_live=false;}
    return 0;
}
static int qcom_pas_shutdown_poll_decrypt(qcom_pas *) { assert(false);return -EIO; }
static void qcom_sysmon_prepare_shutdown(void *,bool) { notices++; }
static int qcom_smem_bust_hwspin_lock_by_host(unsigned host) { assert(host==5);return 0; }
CPP
for f in qcom_pas_boot_allowed qcom_pas_handover qcom_pas_halt qcom_pas_prepare_stop \
    qcom_pas_stop qcom_cliffs_cdsp_start_inner qcom_cliffs_cdsp_start; do
    awk -v f="$f" '$0 ~ "^static (bool|void|int) " f "\\(" {p=1} p{print} p&&/^}/{exit}' "$source_file" >> "$work/check.cpp"
done
cat >> "$work/check.cpp" <<'CPP'
static void reset(qcom_pas &p,clk &xo,clk &aggre,context &main,context &dtb) {
    p=qcom_pas{};p.xo=&xo;p.aggre2_clk=&aggre;p.pas_ctx=&main;p.dtb_pas_ctx=&dtb;active=&p;
    step=0;primary_error=dtb_error=proxy_error=0;main_live=dtb_live=main_map=dtb_map=rails=handed=ready=false;
    unmaps=metadata=notices=primary_stops=dtb_stops=0;assert(!xo.refs&&!aggre.refs);
}
static void complete(rproc &r) {
    assert(!qcom_pas_prepare_stop(&r));assert(!qcom_pas_stop(&r));
    auto &p=*r.priv;
    assert(!main_live&&!dtb_live&&!main_map&&!dtb_map&&!rails&&!p.q6v5.prepared);
    assert(!p.xo->refs&&!p.aggre2_clk->refs&&!p.firmware&&p.stop_phase==QCOM_PAS_STOP_DONE);
    unsigned a=primary_stops,b=dtb_stops,c=unmaps,d=metadata;
    assert(!qcom_pas_stop(&r)&&a==primary_stops&&b==dtb_stops&&c==unmaps&&d==metadata);
}
int main() {
    qcom_pas p;clk xo,aggre;context main{18},dtb{37};firmware fw;rproc r{&p};
    for(int at=0;at<10;at++)for(int stop_fault=0;stop_fault<3;stop_fault++) {
        reset(p,xo,aggre,main,dtb);fault=at;p.firmware=&fw;
        assert(qcom_cliffs_cdsp_start(&r)<0&&p.cdsp_start_failed&&!p.firmware);
        const bool had_main=main_live,had_dtb=dtb_live;const bool map_main=main_map,map_dtb=dtb_map;
        if((stop_fault==0&&had_main)||(stop_fault==1&&had_dtb)) {
            primary_error=stop_fault==0?-EACCES:0;dtb_error=stop_fault==1?-EBUSY:0;
            assert(qcom_pas_prepare_stop(&r)<0);
            assert(main_map==map_main&&dtb_map==map_dtb&&!metadata&&!unmaps);
            assert(qcom_pas_prepare_stop(&r)<0&&!unmaps&&!metadata);
            primary_error=dtb_error=0;
        } else if(stop_fault==2) {
            proxy_error=-EIO;assert(!qcom_pas_prepare_stop(&r));
            assert(qcom_pas_stop(&r)==-EIO&&!main_live&&!dtb_live);
            proxy_error=0;
        }
        complete(r);
    }
    reset(p,xo,aggre,main,dtb);fault=-1;p.firmware=&fw;
    assert(!qcom_cliffs_cdsp_start(&r)&&!p.cdsp_start_failed&&main_live&&dtb_live);
    // IRQ handover already released clocks: normal stop must not release twice.
    qcom_pas_handover(&p.q6v5);handed=true;assert(!xo.refs&&!aggre.refs);
    primary_error=-EACCES;unsigned prior=metadata;assert(qcom_pas_prepare_stop(&r)==-EACCES);
    assert(main_map&&dtb_map&&metadata==prior);primary_error=0;complete(r);
    puts("PASS: ten actual CDSP start failures, both refused PAS stops, proxy retry, firmware reference and handover ownership; COPR only");
}
CPP
"${CXX:-c++}" -std=gnu++20 -O1 -Wall -Wextra -Werror -Wno-unused-parameter \
    -fsanitize=address,undefined -fno-omit-frame-pointer "$work/check.cpp" -o "$work/check"
"$work/check"
