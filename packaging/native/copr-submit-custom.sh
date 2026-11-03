#!/usr/bin/env bash
# Native curl/jq orchestration: never invoke Python copr-cli on the tablet.
set -Eeuo pipefail
umask 077
check=false
if [[ ${1:-} == --check ]]; then check=true; shift; fi
[[ $# == 3 ]] || { printf 'Usage: copr-submit-custom.sh [--check] OWNER PROJECT_DIR SCRIPT\n' >&2; exit 2; }
owner=$1
directory=$2
script=$(realpath "$3")
[[ $owner =~ ^[a-zA-Z0-9_.-]+$ && $directory =~ ^[a-zA-Z0-9_.-]+(:custom:[a-zA-Z0-9_.-]+)?$ ]]
test -s "$script"
[[ $(stat -Lc %s "$script") -le 65536 ]]
project=${directory%%:*}
credentials=${COPR_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/copr}
[[ $(stat -Lc %u "$credentials") == "$(id -u)" ]]
case $(stat -Lc %a "$credentials") in 400|600) ;; *) printf 'COPR credentials require private file permissions\n' >&2; exit 1;; esac
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
# Values go directly from the private INI file to a private curl config. They
# never enter process arguments, shell variables, environment or tool output.
awk '
 /^\[/ {section=$0;next}
 section=="[copr-cli]" || section=="[Copr]" {
  at=index($0,"=");if(!at)next
  key=substr($0,1,at-1);value=substr($0,at+1)
  gsub(/^[[:space:]]+|[[:space:]]+$/,"",key)
  gsub(/^[[:space:]]+|[[:space:]]+$/,"",value)
  if(key=="login")login=value
  if(key=="token")token=value
  if(key=="copr_url")url=value
 }
 END {
  if(login!~/^[A-Za-z0-9_.+\/-]+$/ || token!~/^[A-Za-z0-9_.+\/=\-]+$/ ||
     (url!="https://copr.fedorainfracloud.org" && url!="https://copr.fedorainfracloud.org/"))exit 1
  printf "user = \"%s:%s\"\n",login,token
 }
' "$credentials" > "$work/auth.curl"
jq -n --arg owner "$owner" --arg project "$project" --arg directory "$directory" \
 --rawfile script "$script" '{ownername:$owner,projectname:$project,project_dirname:$directory,
 script:$script,chroot:"fedora-rawhide-aarch64",
 builddeps:"git bash curl coreutils rpm-build cpio gawk tar xz findutils jq",
 resultdir:"result",chroots:["fedora-rawhide-aarch64"],enable_net:false,background:false}' \
 > "$work/request.json"
endpoint=build/create/custom
if [[ $check == true ]]; then
 endpoint=build/check-before-build
 jq 'del(.script,.chroot,.builddeps,.resultdir)' "$work/request.json" > "$work/check.json"
 mv "$work/check.json" "$work/request.json"
fi
# Do not retry a POST: an observation failure may follow successful creation.
curl --disable --silent --show-error --fail-with-body --max-time 90 --proto '=https' \
 --config "$work/auth.curl" --header 'Content-Type: application/json' \
 --data-binary "@$work/request.json" \
 "https://copr.fedorainfracloud.org/api_3/$endpoint" > "$work/response.json"
jq -e 'type=="object" and .error?==null' "$work/response.json" >/dev/null
if [[ $check == true ]]; then
 printf '{"admission_checked":true}\n'
else
 jq -e '{id:(.id|select(type=="number")),state,project_dirname}' "$work/response.json"
fi
