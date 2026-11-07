#!/usr/bin/env bash
# One tuple for source, Image, modules, DT, UCM, firmware aliases and RPMs.
set -Eeuo pipefail
kernel_release_json() {
 jq -ce '
  def version: type=="string" and test("^[1-9][0-9]*[.](0|[1-9][0-9]*)[.](0|[1-9][0-9]*)$");
  def counter: type=="number" and .==floor and .>=1 and .<=2147483647;
  . as $p | $p.upstream as $u |
  if .schema_version==1 and .package=="senemos-uke-linux-kernel-mainline-unstable" and
     .channel=="uke-linux-unstable" and ($u.version|version) and
     (.full_release|counter) and (.source_check_release|counter) and
     ($u.source_sha256|test("^[a-f0-9]{64}$")) and ($u.commit|test("^[a-f0-9]{40}$")) and
     $u.source_url==("https://cdn.kernel.org/pub/linux/kernel/v"+($u.version|split(".")[0])+".x/linux-"+$u.version+".tar.xz") and
     $u.signature_url==("https://cdn.kernel.org/pub/linux/kernel/v"+($u.version|split(".")[0])+".x/linux-"+$u.version+".tar.sign") and
     $u.primary_signer=="647F28654894E3BD457199BE38DBBDC86092693E" and
     ($u.released_epoch|type=="number" and .==floor and .>0 and .<=now) then
    ($u.version+"-"+(.full_release|tostring)) as $evr |
    ("uke"+($u.version|gsub("[.]";"_"))+"-"+(.full_release|tostring)+"u") as $audio |
    if ($audio|length)<16 then {
      version:$u.version,release:.full_release,evr:$evr,kernel_release:($evr+"-unstable"),
      localversion:("-"+(.full_release|tostring)+"-unstable"),audio_driver:$audio,
      firmware_alias:("uke"+$evr+"u"),source_check_evr:($u.version+"-"+(.source_check_release|tostring)),
      source_check_release:.source_check_release,upstream:$u,package:.package,channel:.channel
    } else error("Audio driver tuple exceeds the retained ALSA limit") end
  else error("Invalid cumulative release plan") end' "${1:?Release plan}"
}
kernel_next_release() {
 local history=${1:?Complete package build history} version=${2:?Upstream version} package=${3:?Package}
 [[ $version =~ ^[1-9][0-9]*\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
 jq -er --arg version "$version" --arg package "$package" '
  if (.items|type)!="array" then error("Incomplete build history") else
   if $package=="senemos-uke-linux-kernel-mainline-unstable" and
      any(.items[]; .state!="succeeded" and .state!="failed" and .state!="canceled" and .state!="skipped" and .state!="forked") then
    error("A full kernel job is still active; keep its actual handle")
   else . end |
   [.items[]|select(.source_package.name==$package and
    (if $package=="senemos-uke-linux-kernel-mainline-unstable" then
       .state=="succeeded" or .state=="forked" or .published_binary==true
     else .state=="succeeded" or (.source_package.url|type=="string" and length>0) end))|
    select($package!="uke-kernel-migration-check" or (.source_package.version|startswith($version+"-")))|
    .source_package.version|
    if type=="string" and test("^[1-9][0-9]*[.](?:0|[1-9][0-9]*)[.](?:0|[1-9][0-9]*)-[1-9][0-9]*(?:[.]fc[0-9]+)?$") then
     capture("^(?<version>[1-9][0-9]*[.](?:0|[1-9][0-9]*)[.](?:0|[1-9][0-9]*))-(?<release>[1-9][0-9]*)(?:[.]fc[0-9]+)?$")
    else error("Unrecognized package version in build history") end|
    .release|=tonumber] as $rows |
   if any($rows[];(.version|split(".")|map(tonumber))>($version|split(".")|map(tonumber))) then
    error("Refusing an upstream downgrade")
   else [$rows[]|select(.version==$version)|.release]|unique|sort as $r |
    if ($r|length)==0 then 1
    elif $r==[range(1;($r[-1]+1))] then $r[-1]+1
    else error("Published release gap requires ledger reconciliation") end
   end
  end' "$history"
}
if [[ ${BASH_SOURCE[0]} == "$0" ]];then
 case ${1:-} in
  json) [[ $# == 2 ]];kernel_release_json "$2";;
  next) [[ $# == 4 ]];kernel_next_release "$2" "$3" "$4";;
  *) printf 'Usage: kernel-release.sh json PLAN | next COMPLETE_HISTORY VERSION PACKAGE\n' >&2;exit 2;;
 esac
fi
