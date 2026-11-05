#!/usr/bin/env bash
# COPR source/check worker only; no native compilation on the tablet.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
owner=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?Pass the remote source result directory}")
revision=${2:-1}
[[ $revision =~ ^[1-9][0-9]*$ ]]
bash "$owner/packaging/native/refuse-published-release.sh" uke-o82-hdr-curve-check "1.1.0-$revision"
manifest=manifests/o82-hdr-components-source-20261105.json
(cd "$owner"; jq -r '.inputs[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
mkdir -p "$output" "$stage/uke-o82-hdr-curve-check-1.1.0"
mapfile -t paths < <(jq -r '.inputs[].path' "$owner/$manifest")
git -C "$owner" archive HEAD "${paths[@]}" "$manifest" LICENSE |
    tar -xf - -C "$stage/uke-o82-hdr-curve-check-1.1.0"
git -C "$owner" rev-parse HEAD > "$stage/uke-o82-hdr-curve-check-1.1.0/source-commit"
tar --sort=name --mtime=@1793836800 --owner=0 --group=0 --numeric-owner \
    -czf "$output/uke-o82-hdr-curve-check-1.1.0.tar.gz" -C "$stage" uke-o82-hdr-curve-check-1.1.0
cat > "$output/uke-o82-hdr-curve-check.spec" <<'SPEC'
Name: uke-o82-hdr-curve-check
Version: 1.1.0
Release: @REVISION@%{?dist}
Summary: Typed HDR XML, luminance and panel polynomial source checks
License: MIT
Source0: %{name}-%{version}.tar.gz
BuildArch: noarch
BuildRequires: gcc-c++ clang compiler-rt coreutils jq sed pkgconf-pkg-config
BuildRequires: pkgconfig(json-c) pkgconfig(lcms2) pkgconfig(openssl) pkgconfig(tinyxml2)
%description
Remote checks of the complete typed curve/polynomial component path from the
unchanged production JSON decoder. Independent integer IEEE754 and analytic
oracles, strict malformed-input checks and required precision/duplicate mutants
use only synthetic data. Full HDR policy, kernel integration and physical
acceptance remain open. Only text receipts and a license are installed; no
executable, factory input, private firmware or device writer is packaged.
%prep
%autosetup
jq -r '.inputs[]|.sha256+"  "+.path' manifests/o82-hdr-components-source-20261105.json | sha256sum -c --strict -
%build
set -e
mkdir mutant
sed '/basis\[/s/multiply32(/multiply64(/g' src/display/o82-hdr-pcc.h > mutant/o82-hdr-pcc.h
sed 's/if (!names.insert(name).second)/if (names.insert(name).second \&\& name.empty())/' \
 src/display/o82-hdr-components.hpp > mutant/o82-hdr-components.hpp
cp src/display/o82-hdr-tonemap.h mutant/
! cmp -s src/display/o82-hdr-pcc.h mutant/o82-hdr-pcc.h
! cmp -s src/display/o82-hdr-components.hpp mutant/o82-hdr-components.hpp
# The XML control uses a correct polynomial; precision has its separate executable.
mkdir xml-mutant
cp mutant/o82-hdr-components.hpp src/display/o82-hdr-pcc.h src/display/o82-hdr-tonemap.h xml-mutant/
for compiler in g++ clang++; do
 tag=$(echo "$compiler" | tr + x)
 "$compiler" -std=c++20 -O2 -UNDEBUG -Wall -Wextra -Werror -Imutant \
   tests/o82-hdr-pcc-contract.cpp -o "$tag-pcc-mutant"
 "$compiler" -std=c++20 -O2 -UNDEBUG -Wall -Wextra -Werror -Ixml-mutant -Isrc/display \
   -Wl,--wrap=main tests/o82-hdr-components-contract.cpp \
   $(pkg-config --cflags --libs json-c lcms2 openssl tinyxml2) -o "$tag-xml-mutant"
 for mode in optimized sanitized; do
  flags='-O2'
  if test "$mode" = sanitized; then flags='-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer'; fi
  "$compiler" -std=c++20 $flags -UNDEBUG -Wall -Wextra -Werror -ffp-contract=fast \
    -Isrc/display tests/o82-hdr-curve-contract.cpp -o "$tag-curve-$mode"
  "$compiler" -std=c++20 $flags -UNDEBUG -Wall -Wextra -Werror -ffp-contract=fast \
    -Isrc/display tests/o82-hdr-pcc-contract.cpp -o "$tag-pcc-$mode"
  "$compiler" -std=c++20 $flags -UNDEBUG -Wall -Wextra -Werror -ffp-contract=fast \
    -Isrc/display -Wl,--wrap=main tests/o82-hdr-components-contract.cpp \
    $(pkg-config --cflags --libs json-c lcms2 openssl tinyxml2) -o "$tag-xml-$mode"
 done
done
%install
install -d %{buildroot}%{_docdir}/%{name}
%check
set -e
set -o pipefail
receipt=%{buildroot}%{_docdir}/%{name}/checks.txt
for compiler in gxx clangxx; do
 set +e
 ./$compiler-pcc-mutant --cross-precision-control > pcc-mutant-output.txt 2>&1
 pcc_status=$?
 ./$compiler-xml-mutant --duplicate-control > xml-mutant-output.txt 2>&1
 xml_status=$?
 set -e
 test "$pcc_status" = 43
 test "$xml_status" = 44
 grep -Fx 'Required PCC cross-product precision assertion rejected mutant' pcc-mutant-output.txt | tee -a "$receipt"
 grep -Fx 'Required XML duplicate-field assertion rejected mutant' xml-mutant-output.txt | tee -a "$receipt"
 for mode in optimized sanitized; do
  printf 'Compiler mode: %s %s\n' "$compiler" "$mode" | tee -a "$receipt"
  ./$compiler-curve-$mode | tee -a "$receipt"
  ./$compiler-pcc-$mode | tee -a "$receipt"
  ./$compiler-xml-$mode | tee -a "$receipt"
 done
done
printf 'Original distribution tinyxml2 %s\n' "$(pkg-config --modversion tinyxml2)" | tee -a "$receipt"
install -m644 source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 manifests/o82-hdr-components-source-20261105.json %{buildroot}%{_docdir}/%{name}/source-manifest.json
%files
%license LICENSE
%{_docdir}/%{name}/*
%changelog
* Thu Nov 05 2026 Uke contributors - 1.1.0-@REVISION@
- Check actual JSON decoding, typed private XML, complete panel polynomial and retained curves.
SPEC
sed -i "s/@REVISION@/$revision/g" "$output/uke-o82-hdr-curve-check.spec"
actual=$(rpmspec --target aarch64 -q --srpm --qf '%{NAME} %{VERSION}-%{RELEASE}' "$output/uke-o82-hdr-curve-check.spec")
printf 'Source package identity: %s\n' "$actual"
case "$actual" in
 "uke-o82-hdr-curve-check 1.1.0-$revision"|"uke-o82-hdr-curve-check 1.1.0-$revision.fc46") ;;
 *) echo 'Unexpected HDR component source identity' >&2; exit 1 ;;
esac
