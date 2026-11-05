#!/usr/bin/env bash
# Execute the real Bash reporter with synthetic command results; no unit data.
set -Eeuo pipefail
owner=$(cd -- "$(dirname -- "$0")/.." && pwd)
source_file=${1:-$owner/src/audio/speaker-gain-preflight.sh}
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$work/bin"
# Isolate any installed native reader too: this test never opens a sound device.
sed "s|/usr/bin/uke-speaker-runtime|$work/native-absent|g" "$source_file" > "$work/preflight.sh"
cat > "$work/bin/amixer" <<'SH'
#!/usr/bin/env bash
case $UKE_AUDIO_TEST_QUERY in
 unavailable) exit 1;;
 absent) printf "numid=1,iface=MIXER,name='Ordinary control'\n";;
 partial) printf "numid=1,iface=MIXER,name='FS19xx Protection State'\n";;
 present) printf "numid=1,iface=MIXER,name='FS19xx Protection State'\nnumid=2,iface=MIXER,name='FS19xx Runtime Provisioning'\n";;
 *) exit 2;;
esac
SH
cat > "$work/bin/rpm" <<'SH'
#!/usr/bin/env bash
exit 1
SH
cat > "$work/bin/findmnt" <<'SH'
#!/usr/bin/env bash
printf 'ro,nosuid,nodev,noexec\n'
SH
chmod 755 "$work/bin/"*
export PATH=$work/bin:$PATH
for query in unavailable absent partial present; do
 result=0
 UKE_AUDIO_TEST_QUERY=$query bash "$work/preflight.sh" --json > "$work/report.json" || result=$?
 [[ $result == 2 ]]
 if [[ $query == unavailable ]]; then
  if ! jq -e '(.blockers|index("protected_kernel_controls_unavailable"))!=null and
   (.blockers|index("protected_kernel_controls_missing"))==null' "$work/report.json" >/dev/null; then
   echo 'Preflight misclassifies an inaccessible card as missing protected controls' >&2
   exit 1
  fi
 fi
 jq -e --arg query "$query" '.gain_243_admissible==false and .decision=="blocked" and
  .controls_query_succeeded==($query!="unavailable") and
  .protected_controls_visible==($query=="present") and
  ((.blockers|index("protected_kernel_controls_missing"))!=null)==($query=="absent" or $query=="partial")' "$work/report.json" >/dev/null
done
printf '%s\n' 'Actual preflight distinguishes unavailable, absent, partial and visible controls; every case denies243; no device/calibration read.'
