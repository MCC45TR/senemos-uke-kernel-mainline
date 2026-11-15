#!/usr/bin/bash
# Data-only rebase: keep the signed stable IOVA, power and V4L2 changes.
set -Eeuo pipefail
[[ $# == 2 && -f $1 && ! -e $2 && ! -L $2 ]]
input=$(realpath "$1"); output=$(realpath -m "$2")
case ${input##*/} in
 0008-sm7675-firmware-memory-lifetime.patch)
  kind=8; before=443f337099ef1e296272cb6b9f19d7f95bd4c0f065a721edffcd3ad2743374c7
  after=eaadcd851804a57137ba39ff06af5f5f2e99cdeedb7b84dbc007382e276ac85e;;
 0012-sm7675-checked-power-and-oneshot-irq.patch)
  kind=12; before=83060fc53740f8e8abc18eb655e6c446eb535ce5a0015b72cb82062d898a5261
  after=9df0d9d9c97029100215ffe52cf861352ffcc5d800ca05ac32f8b5dca8d8a3cd;;
 0013-sm7675-codec-caps-and-q16-rates.patch)
  kind=13; before=8e3acbccbcd1ecdbfb23615de58914c85a18c61290736c306134c365ddcf6127
  after=5c225d9cd3de83cb9f5d85ab9e4e6d7518bbc7358f899ce4ae32169e08039282;;
 *) exit 2;;
esac
printf '%s  %s\n' "$before" "$input" | sha256sum -c --strict --quiet -
awk -v kind="$kind" '
 /^@@ / {power=($0=="@@ -236,8 +236,36 @@")}
 kind==8 && $0=="@@ -75,10 +75,14 @@" {$0="@@ -75,11 +75,15 @@";h++}
 kind==12 && $0=="@@ -77,6 +77,8 @@" {$0="@@ -77,7 +77,9 @@";h++}
 kind==12 && power && /^@@ / {$0="@@ -236,9 +236,37 @@";p++;print;next}
 kind==13 && $0==" \tfival->type = V4L2_FRMIVAL_TYPE_STEPWISE;" {
  $0=" \tfival->type = V4L2_FRMIVAL_TYPE_CONTINUOUS;";h++
 }
 kind==13 && $0=="-\tfival->stepwise.step.denominator = MAXIMUM_FPS;" {
  if(getline<=0 || $0!="+\tfival->stepwise.step.denominator = caps->max_frame_rate;")exit 1;
  print " \tfival->stepwise.step.denominator = 1;";n++;next
 }
 {print}
 kind!=13 && $0=="  * @inst_fw_caps_enc: an array of supported instance capabilities by encoder" {
  print "  * @iova_state: a pointer to an array of dma_iova_state entries reserved for restricted IOVA region";n++
 }
 kind==12 && power && $0==" \tiris_disable_unprepare_clock(core, IRIS_HW_CLK);" {
  print " \tiris_disable_power_domains(core, core->pmdomain_tbl->pd_devs[IRIS_HW_POWER_DOMAIN]);";q++
 }
 END {if(h!=1||n!=1||(kind==12&&(p!=1||q!=1)))exit 1}
' "$input" > "$output"
printf '%s  %s\n' "$after" "$output" | sha256sum -c --strict --quiet -
awk -v kind="$kind" '
 /^@@ / {power=($0=="@@ -236,9 +236,37 @@")}
 kind==8 && $0=="@@ -75,11 +75,15 @@" {$0="@@ -75,10 +75,14 @@";h++}
 kind==12 && $0=="@@ -77,7 +77,9 @@" {$0="@@ -77,6 +77,8 @@";h++}
 kind==12 && power && /^@@ / {$0="@@ -236,8 +236,36 @@";p++;print;next}
 kind!=13 && $0=="  * @iova_state: a pointer to an array of dma_iova_state entries reserved for restricted IOVA region" {n++;next}
 kind==12 && power && $0==" \tiris_disable_power_domains(core, core->pmdomain_tbl->pd_devs[IRIS_HW_POWER_DOMAIN]);" {q++;next}
 kind==13 && $0==" \tfival->type = V4L2_FRMIVAL_TYPE_CONTINUOUS;" {
  $0=" \tfival->type = V4L2_FRMIVAL_TYPE_STEPWISE;";h++
 }
 kind==13 && $0==" \tfival->stepwise.step.denominator = 1;" {
  print "-\tfival->stepwise.step.denominator = MAXIMUM_FPS;";
  print "+\tfival->stepwise.step.denominator = caps->max_frame_rate;";n++;next
 }
 {print} END{if(h!=1||n!=1||(kind==12&&(p!=1||q!=1)))exit 1}
' "$output" | cmp - "$input"
printf 'Iris patch%s: exact whole-patch inverse and signed upstream semantics retained.\n' "$kind"
