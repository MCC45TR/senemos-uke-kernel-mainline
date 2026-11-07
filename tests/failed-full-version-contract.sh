#!/usr/bin/env bash
# Metadata-only publication guards; no COPR request or package installation.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d);trap 'find "$work" -depth -delete' EXIT
mkdir "$work/bin"
cat > "$work/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -Eeuo pipefail
case ${*: -1} in
 */api_3/build/list)
  jq -n --arg state "$UKE_GUARD_TEST_STATE" '{items:[{id:42,state:$state,source_package:{name:"senemos-uke-linux-kernel-mainline-unstable",version:"7.3.3-1",url:"https://example.invalid/source.rpm"}}]}' ;;
 */api_3/build/42)
  jq -n --arg state "$UKE_GUARD_TEST_STATE" '{id:42,state:$state,chroots:["fedora-rawhide-aarch64"]}' ;;
 */api_3/build-chroot/42/fedora-rawhide-aarch64)
  printf '%s\n' '{"result_url":"https://download.copr.fedorainfracloud.org/results/mcc45tr/fixture/"}' ;;
 https://download.copr.fedorainfracloud.org/results/mcc45tr/fixture/)
  cat "$UKE_GUARD_TEST_INDEX" ;;
 *) exit 91 ;;
esac
CURL
chmod 700 "$work/bin/curl"
export UKE_GUARD_TEST_INDEX=$work/index UKE_GUARD_TEST_STATE=failed
printf "<a href='kernel-7.3.3-1.src.rpm'>source</a>\n" > "$work/index"
PATH="$work/bin:$PATH" bash "$root/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable 7.3.3-1 > "$work/log"
grep -Fq 'Unpublished terminal full build42 retains version7.3.3-1.' "$work/log"
for quote in "'" '"';do
 printf '<a href=%skernel-7.3.3-1.aarch64.rpm%s>binary</a>\n' "$quote" "$quote" > "$work/index"
 if PATH="$work/bin:$PATH" bash "$root/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable 7.3.3-1 > "$work/log" 2>&1;then exit 1;fi
 grep -Fq 'Failed build published a binary' "$work/log"
done
printf "<a href='kernel-7.3.3-1.src.rpm'>source</a>\n" > "$work/index"
for state in succeeded running;do
 export UKE_GUARD_TEST_STATE=$state
 if PATH="$work/bin:$PATH" bash "$root/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable 7.3.3-1 > "$work/log" 2>&1;then exit 1;fi
done
export UKE_GUARD_TEST_STATE=canceled
PATH="$work/bin:$PATH" bash "$root/packaging/native/refuse-published-release.sh" senemos-uke-linux-kernel-mainline-unstable 7.3.3-1 > "$work/log"
printf 'Failed full version: source-only/canceled retention, both binary-link refusals, published and active refusal passed.\n'
