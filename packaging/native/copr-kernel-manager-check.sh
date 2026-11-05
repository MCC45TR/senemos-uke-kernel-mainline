#!/usr/bin/env bash
# COPR source worker only. Preserve and run the complete postfreeze source gate.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?source result directory}")
revision=${2:-1}
[[ $revision =~ ^[1-9][0-9]*$ ]]
stage=$(mktemp -d)
factory=$owner/packaging/native/manager-base-factory.sh
trap 'rm -f "$factory"; find "$stage" -depth -delete' EXIT
# Use a dedicated check-package namespace, never a kernel revision or a live job.
sed 's/uke-o82-kms-check/uke-manager-resources-check/g' "$owner/packaging/native/copr-postfreeze-union-check.sh" > "$factory"
bash "$factory" "$output" "$revision"
mkdir "$stage/manager-addon"
git -C "$owner" archive HEAD configs/kernel-manager packaging/native/apply-kernel-manager-config.sh \
 packaging/native/check-kernel-manager-config.sh tests/kernel-manager-config-contract.sh LICENSE LICENSES/GPL-2.0-only.txt |
 tar -xf - -C "$stage/manager-addon"
git -C "$owner" rev-parse HEAD > "$stage/manager-addon/source-commit"
epoch=$(git -C "$owner" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf "$output/manager-addon.tar.xz" -C "$stage" manager-addon
spec=$output/uke-manager-resources-check.spec
awk '
 /^Source13:/ {print;print "Source14: manager-addon.tar.xz";sources++;next}
 /^tar -xJf %\{SOURCE13\}$/ {print;print "tar -xJf %{SOURCE14}";preps++;next}
 /^%install$/ {
  print "bash manager-addon/packaging/native/check-kernel-manager-config.sh \"$PWD\" %{_uke_out} | tee -a %{_topdir}/governor-cumulative-checks.txt"
  builds++
 }
 /^%check$/ {print "install -m644 manager-addon/source-commit %{buildroot}%{_docdir}/%{name}/manager-source-commit";installs++}
 {print}
 END {if(sources!=1||preps!=1||builds!=1||installs!=1)exit 1}
' "$spec" > "$stage/manager.spec"
install -m644 "$stage/manager.spec" "$spec"
