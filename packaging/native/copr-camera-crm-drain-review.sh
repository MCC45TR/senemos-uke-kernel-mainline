#!/usr/bin/env bash
# COPR source factory: small native review receipt in the existing check family.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
project=$(cd -- "$(dirname -- "$0")/../.." && pwd)
output=$(realpath -m "${1:?COPR source result directory}")
manifest=$project/manifests/camera-crm-drain-review-20261105.json
(cd "$project"; jq -r '.inputs[]|.sha256+"  "+.path' "$manifest" | sha256sum -c --strict --quiet -)
for channel in uke-linux uke-linux-test uke-linux-unstable; do
    curl -q -fLsS --max-time 45 --get --data-urlencode ownername=mcc45tr \
        --data-urlencode "projectname=$channel" --data-urlencode packagename=uke-o82-kms-check \
        --data-urlencode limit=200 https://copr.fedorainfracloud.org/api_3/build/list |
        jq -e 'all(.items[]; (.source_package.version//"")|test("^7[.]3[.]1-19([.]|$)")|not)' >/dev/null
done
work=$(mktemp -d)
trap 'find "$work" -depth -delete' EXIT
mkdir -p "$output" "$work/uke-o82-kms-check-7.3.1"
mapfile -t assets < <(jq -r '.inputs[].path' "$manifest"; printf '%s\n' manifests/camera-crm-drain-review-20261105.json LICENSE LICENSES/GPL-2.0-only.txt)
git -C "$project" archive HEAD "${assets[@]}" | tar -xf - -C "$work/uke-o82-kms-check-7.3.1"
git -C "$project" rev-parse HEAD > "$work/uke-o82-kms-check-7.3.1/review-source-commit"
epoch=$(git -C "$project" show -s --format=%ct HEAD)
tar --sort=name --mtime="@$epoch" --owner=0 --group=0 --numeric-owner -cJf \
    "$output/uke-o82-kms-check-7.3.1.tar.xz" -C "$work" uke-o82-kms-check-7.3.1
cat > "$output/uke-o82-kms-check.spec" <<'SPEC'
%global debug_package %{nil}
Name: uke-o82-kms-check
Version: 7.3.1
Release: 19%{?dist}
Summary: Independent camera CRM IRQ-drain source regression receipt
License: GPL-2.0-only
Source0: %{name}-%{version}.tar.xz
BuildRequires: gcc clang compiler-rt libasan libubsan patch jq
BuildRequires: bash coreutils diffutils findutils grep sed tar xz
ExclusiveArch: aarch64

%description
Compare the exact qualified camera transport with a proposed post-drain status
check under native compiler and sanitizer fault models. Text evidence only;
no full kernel, final module, target installation or hardware admission.

%prep
%setup -q

%build
set -o pipefail
bash tests/camera-crm-drain-review.sh | tee review-checks.txt

%install
install -Dm644 review-checks.txt %{buildroot}%{_docdir}/%{name}/crm-drain-checks.txt
install -m644 review-source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -m644 manifests/camera-crm-drain-review-20261105.json %{buildroot}%{_docdir}/%{name}/manifest.json
install -m644 docs/camera-crm-drain-review.md %{buildroot}%{_docdir}/%{name}/review.md

%check
test -s %{buildroot}%{_docdir}/%{name}/crm-drain-checks.txt
test -s %{buildroot}%{_docdir}/%{name}/manifest.json

%files
%license LICENSE LICENSES/GPL-2.0-only.txt
%{_docdir}/%{name}/*
SPEC
[[ $(rpmspec --define 'dist %{nil}' --target aarch64 -q --srpm --qf '%{NAME}-%{VERSION}-%{RELEASE}' "$output/uke-o82-kms-check.spec") == uke-o82-kms-check-7.3.1-19 ]]
printf 'Small IRQ-drain source regression prepared; native proof and coordinator integration remain separate\n'
