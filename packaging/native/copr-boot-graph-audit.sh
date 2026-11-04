#!/usr/bin/env bash
# COPR-only native read-only diagnostic. No tablet compilation or FDT export.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
output=$(realpath -m "${1:?COPR output}")
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
mkdir -p "$output" "$output/graph-audit"
for file in graph-audit.c graph-audit.cpp uke-camcc-dt.h uke-front-eeprom-dt.h LICENSE; do
 install -m644 "$owner/src/boot/diagnostics/$file" "$output/graph-audit/$file"
done
cat > "$output/graph-audit/instrument.sh" <<'SCRIPT'
#!/usr/bin/bash
set -Eeuo pipefail
for stage in camcc front; do
 source=uke-camcc-dt.h
 [[ $stage != front ]] || source=uke-front-eeprom-dt.h
 awk '{gsub(/return -FDT_ERR_[A-Z_]+;/,"{ uke_audit_failed_line = __LINE__; & }"); print}' "$source" > "instrumented-$stage.h"
done
SCRIPT
tar -cJf "$output/uke-boot-graph-audit-unstable-0.1.tar.xz" -C "$output" graph-audit
find "$output/graph-audit" -depth -delete
cat > "$output/uke-boot-graph-audit-unstable.spec" <<'SPEC'
Name: uke-boot-graph-audit-unstable
Version: 0.1
Release: 3%{?dist}
%global debug_package %{nil}
Summary: Read-only Uke camera boot graph diagnostics on a RAM copy
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.xz
BuildRequires: gcc gcc-c++ libfdt-devel coreutils
%description
Runs the retained 6000 camera FDT helper code on a private userspace copy.
Only return codes and source line numbers are printed. It never writes the
input or accesses camera devices, EEPROM, physical memory or boot selection.
Current handoff admission is not proof of the original failed boot graph.
%prep
%setup -q -n graph-audit
bash instrument.sh
%build
gcc %{build_cflags} -std=gnu11 -Wall -Wextra -Werror -c graph-audit.c -o graph-audit.o
g++ %{build_cxxflags} -std=c++17 -Wall -Wextra -Werror graph-audit.cpp graph-audit.o %{build_ldflags} -lfdt -o uke-boot-graph-audit-unstable
%check
if ./uke-boot-graph-audit-unstable /dev/null; then exit 1; fi
if ./uke-boot-graph-audit-unstable; then exit 1; fi
%install
install -Dm755 uke-boot-graph-audit-unstable %{buildroot}%{_bindir}/uke-boot-graph-audit-unstable
%files
%license LICENSE
%{_bindir}/uke-boot-graph-audit-unstable
%changelog
* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 0.1-3
- Apply distribution compiler hardening and omit separate debug subpackages.
* Wed Nov 04 2026 MCC45TR <75160848+MCC45TR@users.noreply.github.com> - 0.1-2
- Preserve kernel array-size semantics in the userspace audit adapter.
SPEC
rpmspec --target aarch64 --parse "$output/uke-boot-graph-audit-unstable.spec" >/dev/null
