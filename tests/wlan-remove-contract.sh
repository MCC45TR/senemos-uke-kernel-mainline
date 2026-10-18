#!/usr/bin/env bash
# Execute actual AHB removal callbacks without firmware or hardware access.
set -Eeuo pipefail
source=${1:?Pass prepared kernel}/drivers/net/wireless/ath/ath11k/ahb.c
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cat > "$work/check.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <string.h>
enum {ATH11K_FLAG_QMI_FAIL,ATH11K_FLAG_REGISTERED,ATH11K_FLAG_RECOVERY,ATH11K_FLAG_UNREGISTERING};
#define ATH11K_AHB_RECOVERY_TIMEOUT 5000
struct work_struct {char id;};
struct ath11k_base {unsigned long dev_flags;int driver_recovery;struct work_struct restart_work;struct {struct work_struct event_work;} qmi;};
struct platform_device {struct ath11k_base *ab;};
static char events[32];static unsigned count,warnings;
static unsigned long recovered=1;
static void event(char value) {assert(count+1<sizeof(events));events[count++]=value;events[count]=0;}
static bool test_bit(unsigned bit,const unsigned long *flags) {return !!(*flags&(1UL<<bit));}
static void set_bit(unsigned bit,unsigned long *flags) {*flags|=1UL<<bit;}
static unsigned long wait_for_completion_timeout(int *completion,unsigned long timeout) {(void)completion;assert(timeout==ATH11K_AHB_RECOVERY_TIMEOUT);event('W');return recovered;}
#define ath11k_warn(...) (++warnings)
static void cancel_work_sync(struct work_struct *work) {event(work->id);}
static struct ath11k_base *platform_get_drvdata(struct platform_device *pdev) {return pdev->ab;}
static void prepared(struct ath11k_base *ab) {assert(test_bit(ATH11K_FLAG_UNREGISTERING,&ab->dev_flags));assert(count>=2&&events[count-2]=='R'&&events[count-1]=='Q');}
static void ath11k_ahb_power_down(struct ath11k_base *ab,bool reset) {prepared(ab);assert(!reset);event('P');}
static void ath11k_debugfs_soc_destroy(struct ath11k_base *ab) {assert(ab);event('D');}
static void ath11k_qmi_deinit_service(struct ath11k_base *ab) {assert(ab);event('M');}
static void ath11k_core_deinit(struct ath11k_base *ab) {prepared(ab);assert(test_bit(ATH11K_FLAG_REGISTERED,&ab->dev_flags));assert(!test_bit(ATH11K_FLAG_QMI_FAIL,&ab->dev_flags));event('C');}
static void ath11k_fw_destroy(struct ath11k_base *ab) {assert(ab);event('F');}
static void ath11k_ahb_free_resources(struct ath11k_base *ab) {assert(ab);event('Z');}
C
for signature in 'static void ath11k_ahb_remove_prepare(' 'static void ath11k_ahb_remove('; do
 awk -v signature="$signature" 'index($0,signature)==1 {emit=1;found=1} emit {print} emit&&/^}/ {exit} END {if(!found)exit 1}' "$source" >> "$work/check.c"
done
cat >> "$work/check.c" <<'C'
static void run(unsigned long flags,const char *expected,unsigned expected_warnings) {
 struct ath11k_base ab={.dev_flags=flags,.restart_work={'R'},.qmi={.event_work={'Q'}}};
 struct platform_device pdev={&ab};count=warnings=0;events[0]=0;
 ath11k_ahb_remove(&pdev);
 assert(!strcmp(events,expected)&&warnings==expected_warnings);
}
int main(void) {
 run(0,"RQPDMFZ",0); /* Bound before the firmware service appears. */
 run(1UL<<ATH11K_FLAG_REGISTERED,"RQCFZ",0);
 run(1UL<<ATH11K_FLAG_QMI_FAIL,"RQPDMFZ",0);
 run((1UL<<ATH11K_FLAG_REGISTERED)|(1UL<<ATH11K_FLAG_QMI_FAIL),"RQPDMFZ",0);
 recovered=1;run((1UL<<ATH11K_FLAG_REGISTERED)|(1UL<<ATH11K_FLAG_RECOVERY),"WRQCFZ",0);
 recovered=0;run((1UL<<ATH11K_FLAG_REGISTERED)|(1UL<<ATH11K_FLAG_RECOVERY),"WRQCFZ",1);
 return 0;
}
C
"${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror "$work/check.c" -o "$work/check"
"$work/check"
printf '%s\n' 'Actual AHB removal: drain first, partial cleanup before registration, full registered cleanup, QMI failure and recovery paths passed'
