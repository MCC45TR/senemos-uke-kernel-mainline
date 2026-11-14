#!/usr/bin/bash
# COPR only: preserve native108 and add an isolated read-only SSC layer.
set -Eeuo pipefail
[[ $# == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
manifest=$owner/manifests/ssc-time-reference-20261113.json
output=$(realpath -m "$1")
[[ ! -e $output && -z $(git -C "$owner" status --porcelain) ]]
(cd "$owner";jq -r '.source_assets[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
curl -qfsSL --retry 2 --max-time 600 "$(jq -er .parent_srpm_url "$manifest")" -o "$work/parent.src.rpm"
printf '%s  %s\n' "$(jq -er .parent_srpm_sha256 "$manifest")" "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{SOURCEPACKAGE}' "$work/parent.src.rpm") == uke-kernel-migration-check-7.3.3-108.1 ]]
rpm2cpio "$work/parent.src.rpm" > "$work/parent.cpio"
cpio -t --quiet < "$work/parent.cpio" > "$work/paths"
awk '/^\/|(^|\/)\.\.($|\/)/{bad=1}END{exit bad}' "$work/paths"
mkdir "$output"
(cd "$output";cpio -idm --quiet --no-absolute-filenames < "$work/parent.cpio")
spec=$output/uke-kernel-migration-check.spec
printf '%s  %s\n' "$(jq -er .parent_spec_sha256 "$manifest")" "$spec" | sha256sum -c --strict --quiet -
find "$output" -maxdepth 1 -type f ! -name uke-kernel-migration-check.spec -print0 | sort -z | xargs -0 sha256sum > "$work/retained.sha256"
mapfile -t assets < <(jq -er '.source_assets[].path' "$manifest")
git -C "$owner" archive --prefix=ssc-time-reference/ HEAD "${assets[@]}" manifests/ssc-time-reference-20261113.json LICENSES/GPL-2.0-only.txt | tar -xf - -C "$work"
git -C "$owner" rev-parse HEAD > "$work/ssc-time-reference/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/uke-ssc-time-reference.tar.xz" -C "$work" ssc-time-reference
node - "$spec" <<'JS'
const fs=require('fs'),p=process.argv[2],before=fs.readFileSync(p,'utf8');let after=before;const changes=[];function once(a,b){if(after.split(a).length!==2)throw Error('Native108 recipe anchor');after=after.replace(a,()=>b);changes.push([a,b]);}
once('Release: 108%{?dist}','Release: 110%{?dist}');
once('Source191: uke-ssc-stream-freshness.tar.xz','Source191: uke-ssc-stream-freshness.tar.xz\nSource192: uke-ssc-time-reference.tar.xz');
once('\n%build\n','\ntar -xJf %{SOURCE192}\n(cd ssc-time-reference; jq -r \'.source_assets[]|.sha256+"  "+.path\' manifests/ssc-time-reference-20261113.json | sha256sum -c --strict --quiet -)\n\n%build\n');
once('\n%install\n',`
bash ssc-time-reference/src/sensors/apply-time-reference733.sh "$PWD" "$PWD/ssc-time-reference" | tee -a %{_topdir}/camcc-resource-checks.txt
bash ssc-time-reference/tests/ssc-time-reference.sh drivers/iio/common/uke-ssc/uke-ssc-iio.c | tee -a %{_topdir}/camcc-resource-checks.txt
rm resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o
make ARCH=arm64 LLVM=1 LLVM_IAS=1 O="$PWD/resource-object" LOCALVERSION=-24-unstable KCFLAGS=-Werror -j4 drivers/iio/common/uke-ssc/uke-ssc-iio.o
llvm-readelf -h resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o | grep -F AArch64
llvm-nm --defined-only resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o | grep -E ' [tT] ssc_time_reference_show$'
llvm-nm --undefined-only resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o | grep -F arch_timer_read_counter
if llvm-nm --undefined-only resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o | grep -F arch_timer_get_rate;then exit 1;fi
grep -aqF 'schema=1 admitted=0 generation=' resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o
sha256sum resource-object/drivers/iio/common/uke-ssc/uke-ssc-iio.o drivers/iio/common/uke-ssc/uke-ssc-iio.c | tee -a %{_topdir}/camcc-resource-checks.txt
printf 'Actual SSC time-reference AArch64 object/root attribute/exported counter interface passed;clock/frame mapping unadmitted\\n' | tee -a %{_topdir}/camcc-resource-checks.txt
\n%install\n`);
once('\n%check\n',`
install -m644 camcc-resource/source-commit %{buildroot}%{_datadir}/%{name}/parent-native108-source-commit
install -m644 ssc-time-reference/source-commit ssc-time-reference/manifests/ssc-time-reference-20261113.json ssc-time-reference/src/sensors/sysfs-driver-uke-ssc-time-reference %{buildroot}%{_datadir}/%{name}/
\n%check\n`);
once('* Fri Nov 13 2026 Uke contributors - 7.3.3-108','* Fri Nov 13 2026 Uke contributors - 7.3.3-110\n- Qualify a root-only demand snapshot before SSC hardware-clock admission.');
let inverse=after;for(const[a,b]of changes.reverse()){if(inverse.split(b).length!==2)throw Error('Native110 inverse anchor');inverse=inverse.replace(b,()=>a);}if(inverse!==before)throw Error('Unrelated native recipe edit');fs.writeFileSync(p,after);
JS
sha256sum -c --strict --quiet "$work/retained.sha256"
printf 'Native110 constructor:exact native108 whole recipe inverse and all source assets retained;root-only diagnostic and actual final SSC object added. No full Image or device operation.\n'
