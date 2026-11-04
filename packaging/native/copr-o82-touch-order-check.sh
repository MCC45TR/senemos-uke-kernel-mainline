#!/usr/bin/env bash
# COPR only: reuse the diagnostic fixture family; never produce a kernel RPM.
set -Eeuo pipefail
trap 'status=$?; printf "Touch fixture source failed at line %s (exit %s)\n" "$LINENO" "$status" >&2; exit "$status"' ERR
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
bash "$owner/packaging/native/refuse-published-release.sh" uke-o82-kms-check 7.3.1-13
output=$(realpath -m "${1:?Pass the remote source result directory}")
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
[[ $(curl -fLsS --max-time 45 https://copr.fedorainfracloud.org/api_3/build/11260288 | jq -er .state) == succeeded ]]
curl -fLsS --retry 2 --max-time 300 --proto '=https' --proto-redir '=https' \
 https://download.copr.fedorainfracloud.org/results/mcc45tr/uke-linux-unstable/srpm-builds/11260288/senemos-uke-linux-kernel-mainline-unstable-7.3.1-11003.src.rpm \
 -o "$stage/parent.src.rpm"
[[ $(rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$stage/parent.src.rpm") == senemos-uke-linux-kernel-mainline-unstable-7.3.1-11003 ]]
[[ $(rpm -qp --qf '%{SHA256HEADER}' "$stage/parent.src.rpm") == fe81d7b500042e72ebbe305534582953a0def06f3e553ed72d50912361cc030a ]]
[[ $(rpm -qp --qf '%{PAYLOADSHA256}' "$stage/parent.src.rpm") == aa0dc274e5d95568a25a35d132b931561beda627af5a1924b45f613427f4ef76 ]]
rpmkeys --checksig --nosignature --verbose "$stage/parent.src.rpm"
printf 'Qualified11003 full source RPM SHA256: '
sha256sum "$stage/parent.src.rpm"
rpm2cpio "$stage/parent.src.rpm" > "$stage/parent.cpio"
cpio -t --quiet < "$stage/parent.cpio" > "$stage/entries"
awk '/^\/|(^|\/)\.\.($|\/)/ {bad=1} END {exit bad}' "$stage/entries"
mkdir -p "$output" "$stage/addon"
(cd "$output"; cpio -idm --quiet --no-absolute-filenames < "$stage/parent.cpio")
parent=$output/senemos-uke-linux-kernel-mainline-unstable.spec
[[ $(grep -c '^Source9:' "$parent") == 0 ]]
[[ $(grep -Fxc '%prep' "$parent") == 1 && $(grep -Fxc '%build' "$parent") == 1 ]]
find "$output" -maxdepth 1 -type f ! -name '*.spec' -print0 | sort -z | xargs -0 sha256sum > "$stage/retained.sha256"
git -C "$owner" archive --prefix=native-addon/ HEAD \
 patches/display/0074-o82-touch-retain-before-off.patch \
 patches/display/0074-o82-touch-retain-test.patch \
 tests/o82-touch-order-regression.sh src/input/nt36532-uke-protocol.c \
 docs/O82-TOUCH-BLANK-ORDER.md LICENSE LICENSES/GPL-2.0-only.txt | tar -xf - -C "$stage/addon"
git -C "$owner" rev-parse HEAD > "$stage/addon/native-addon/source-commit"
tar --sort=name --mtime="@$(git -C "$owner" show -s --format=%ct HEAD)" \
 --owner=0 --group=0 --numeric-owner -cJf "$output/uke-o82-touch-order-source.tar.xz" \
 -C "$stage/addon" native-addon
spec=$output/uke-o82-kms-check.spec
awk '
 /^%description/ {exit}
 /^Name:/ {$0="Name: uke-o82-kms-check"}
 /^Release:/ {$0="Release: 13%{?dist}"}
 /^Summary:/ {$0="Summary: Retained Uke TDDI early-blank ordering callback check"}
 /^(Requires|Provides|Recommends):/ {next}
 {print}
' "$parent" > "$spec"
cat >> "$spec" <<'SPEC'
Source9: uke-o82-touch-order-source.tar.xz

%description
Execute qualified11003 panel callbacks with an independently observed OEM
early-blank contract. Check original failure and corrected lifecycle/error
paths under GCC/Clang sanitizers, plus the retained touch protocol. Only a
text receipt is packaged. No kernel, module or boot image is produced.

SPEC
awk '/^%prep$/ {emit=1} /^%build$/ {exit} emit {print}' "$parent" >> "$spec"
cat >> "$spec" <<'SPEC'
tar -xJf %{SOURCE9}

%build
set -o pipefail
bash native-addon/tests/o82-touch-order-regression.sh "$PWD" \
 | tee %{_topdir}/o82-touch-order-checks.txt

%install
install -Dm644 %{_topdir}/o82-touch-order-checks.txt \
 %{buildroot}%{_docdir}/%{name}/checks.txt
install -m644 native-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit

%check
test -s %{buildroot}%{_docdir}/%{name}/checks.txt

%files
%license native-addon/LICENSE native-addon/LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/checks.txt
%{_docdir}/%{name}/source-commit

%changelog
* Wed Nov 04 2026 Uke contributors - 7.3.1-13
- Check OEM touch retention before panel OFF, including fault cleanup.
- Qualify the already-read final ACK diagnostic on the retained protocol.
- Reset fixture ON packet accounting between complete powered lifecycles.
SPEC
sha256sum -c "$stage/retained.sha256"
rm "$parent"
# COPR's source worker does not promise a binary-chroot dist macro.
candidate=$(rpmspec --define 'dist %{nil}' --target aarch64 -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$spec")
printf 'Fixture source candidate: %s\n' "$candidate"
[[ $candidate == uke-o82-kms-check-7.3.1-13 ]]
