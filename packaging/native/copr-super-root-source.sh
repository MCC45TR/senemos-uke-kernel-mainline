#!/usr/bin/bash
# COPR source worker only; fetch the exact public full3 source, no compilation.
set -Eeuo pipefail
[[ $# == 1 && $(uname -m) == aarch64 && ${UKE_COPR_SOURCE_WORKER:-} == 1 && ! -e /etc/senemos/kernel-update.conf ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
result=$(realpath -m "$1")
[[ ! -e $result && ! -L $result ]]
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir "$result" "$work/super-root" "$work/parent"
curl -qfsSL --max-time 600 --max-filesize 209715200 \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11333235/senemos-uke-linux-kernel-mainline-unstable-7.3.4-3.src.rpm \
 -o "$work/parent.src.rpm"
printf '%s  %s\n' 8343162259135cbc962ac1a06bd42f062908a684d29e48f53ff7c8bb8bd8c32a "$work/parent.src.rpm" | sha256sum -c --strict --quiet -
rpm2cpio "$work/parent.src.rpm" | cpio -i --to-stdout --quiet ./senemos-native-profile-7.3.4.tar.xz | \
 tar -xJf - -C "$work/parent" native-profile/src/boot/uke-root-selector.h native-profile/tests/root-selector-contract.cpp
printf '%s  %s\n' c9d89868ba59eb70d042bbb3f70f8c036a3b45004e9f82c2a2accd1bb7cde94d "$work/parent/native-profile/src/boot/uke-root-selector.h" | sha256sum -c --strict --quiet -
install -m644 "$work/parent/native-profile/src/boot/uke-root-selector.h" "$work/super-root/parent-root-selector.h"
install -m644 "$work/parent/native-profile/tests/root-selector-contract.cpp" "$work/super-root/parent-root-selector-test.cpp"
install -m644 "$owner/src/boot/super-root734/uke-super-root-selector.h" "$work/super-root/"
install -m644 "$owner/tests/super-root734.cpp" "$work/super-root/"
install -m644 "$owner/LICENSE" "$work/super-root/"
git -C "$owner" rev-parse HEAD > "$work/super-root/source-commit"
(cd "$work/super-root";find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar --sort=name --mtime=@1794787200 --owner=0 --group=0 --numeric-owner -cJf "$result/uke-super-root-source.tar.xz" -C "$work" super-root
install -m644 "$owner/packaging/native/uke-super-root-source-check.spec" "$result/"
[[ $(rpmspec --target aarch64 --define 'dist .fc46' -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$result/uke-super-root-source-check.spec") == uke-super-root-source-check-0.1-1.fc46 ]]
printf 'Native rescue parser source check assembled; packaged parent header only, prepared kernel/initrd integration remains unqualified.\n'
