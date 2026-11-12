#!/usr/bin/bash
# COPR-only additive source check; no device transaction or full kernel image.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/ssc-stream-freshness-20261113.json
output=$(realpath -m "$1")
[[ $(curl -qfsSL --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11318457 | jq -er .state) == failed ]]
(cd "$owner"; jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
bash "$owner/packaging/native/copr-camcc-resource733-check.sh" "$output"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mapfile -t assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=ssc-stream-freshness/ HEAD "${assets[@]}" \
 manifests/ssc-stream-freshness-20261113.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/ssc-stream-freshness/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner \
 -cJf "$output/uke-ssc-stream-freshness.tar.xz" -C "$stage" ssc-stream-freshness
node - "$output/uke-kernel-migration-check.spec" <<'JS'
const fs=require('fs'),p=process.argv[2];let s=fs.readFileSync(p,'utf8');
function replaceOnce(old,next){if(s.split(old).length!==2)throw Error('Inherited recipe drift: '+old);s=s.replace(old,next);}
if(!s.includes('Release: 106%{?dist}'))throw Error('Wrong cumulative source-check release');
replaceOnce('Source190: uke-camcc-resource.tar.xz','Source190: uke-camcc-resource.tar.xz\nSource191: uke-ssc-stream-freshness.tar.xz');
replaceOnce('\n%build\n',`\ntar -xJf %{SOURCE191}
bash ssc-stream-freshness/src/sensors/apply-stream-freshness733.sh "$PWD" "$PWD/ssc-stream-freshness"
cp drivers/iio/common/uke-ssc/uke-ssc-iio.c %{_topdir}/ssc-final-source.c
git apply -R ssc-stream-freshness/src/sensors/0019-ssc-streaming-buffer-fresh-sample.patch
printf '%s  %s\\n' f7c689e893e8696dcf093cf859dbb07dfc6b31b5332ce4108a19be13252efca1 drivers/iio/common/uke-ssc/uke-ssc-iio.c | sha256sum -c --strict -
git apply ssc-stream-freshness/src/sensors/0019-ssc-streaming-buffer-fresh-sample.patch
cmp %{_topdir}/ssc-final-source.c drivers/iio/common/uke-ssc/uke-ssc-iio.c
\n%build\n`);
replaceOnce('\n%install\n',`
bash ssc-stream-freshness/tests/ssc-stream-freshness.sh drivers/iio/common/uke-ssc/uke-ssc-iio.c include/uapi/linux/iio/types.h | tee -a %{_topdir}/camcc-resource-checks.txt
bash native-profile/tests/ssc-quaternion-buffer.sh "$PWD" | tee -a %{_topdir}/camcc-resource-checks.txt
bash native-profile/tests/ssc-heading-callbacks.sh "$PWD" | tee -a %{_topdir}/camcc-resource-checks.txt
bash native-profile/tests/ssc-proximity-abi.sh "$PWD" | tee -a %{_topdir}/camcc-resource-checks.txt
grep -E '^CONFIG_IIO_UKE_SSC=[my]$' resource-object/.config
make ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$PWD/resource-object" LOCALVERSION=-24-unstable KCFLAGS=-Werror -j4 drivers/iio/common/uke-ssc/uke-ssc-iio.o drivers/iio/common/uke-ssc/uke-ssc-protocol.o
for object in resource-object/drivers/iio/common/uke-ssc/uke-ssc-{iio,protocol}.o;do
 llvm-readelf -h "$object" | grep -E 'Machine:.*AArch64'
 sha256sum "$object" | tee -a %{_topdir}/camcc-resource-checks.txt
done
sha256sum drivers/iio/common/uke-ssc/uke-ssc-iio.c | tee -a %{_topdir}/camcc-resource-checks.txt
\n%install\n`);
replaceOnce('\n%check\n',`\ninstall -m644 ssc-stream-freshness/manifests/ssc-stream-freshness-20261113.json %{buildroot}%{_datadir}/%{name}/
\n%check\n`);
replaceOnce('* Fri Nov 13 2026 Uke contributors - 7.3.3-106','* Fri Nov 13 2026 Uke contributors - 7.3.3-106\n- Require a fresh streaming report when joining an existing SSC buffer.');
fs.writeFileSync(p,s);
JS
