#!/usr/bin/env bash
# Essential independent native check; no full kernel or target package install.
set -Eeuo pipefail
test ! -e /etc/senemos/kernel-update.conf
[[ $(rpm --eval '%{_host_cpu}') == aarch64 && $(rpm --eval '%{fedora}') == 46 ]]
owner=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
output=$(realpath -m "${1:?COPR result directory}")
[[ ! -e $output || (-d $output && -z $(find "$output" -mindepth 1 -maxdepth 1 -print -quit)) ]]
mkdir -p "$output"
stage=$(mktemp -d)
trap 'find "$stage" -depth -delete' EXIT
assets=(src/display/atomic-perf/0001-dpu-bw-checked-state.patch
 src/display/atomic-perf/apply-checked-state.sh tests/fixtures/dpu-checked-state.c
 tests/dpu-checked-state-contract.sh tests/dpu-checked-state-qualify.sh docs/DPU-CHECKED-STATE.md)
git -C "$owner" archive --prefix=dpu-addon/ HEAD "${assets[@]}" | tar -xf - -C "$stage"
git -C "$owner" rev-parse HEAD > "$stage/dpu-addon/source-commit"
tar --sort=name --mtime="@$(git -C "$owner" show -s --format=%ct HEAD)" --owner=0 --group=0 --numeric-owner \
 -cJf "$output/uke-dpu-checked-state.tar.xz" -C "$stage" dpu-addon
curl -q -fLsS --retry 2 --max-time 600 https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.3.1.tar.xz -o "$output/linux-7.3.1.tar.xz"
printf '%s  %s\n' fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231 "$output/linux-7.3.1.tar.xz" | sha256sum -c --strict -
cat > "$output/uke-dpu-perf-check.spec" <<'SPEC'
Name: uke-dpu-perf-check
Version: 7.3.1
Release: 1%{?dist}
Summary: Native evidence for checked-state DPU bandwidth calculation
License: GPL-2.0-only
Source0: linux-7.3.1.tar.xz
Source1: uke-dpu-checked-state.tar.xz
BuildRequires: gcc gcc-c++ clang compiler-rt llvm lld make bc flex bison openssl-devel elfutils-libelf-devel perl git-core
ExclusiveArch: aarch64
%global debug_package %{nil}

%description
Text evidence only. Executes actual DPU performance callbacks and DRM iterator
against old/new atomic state, with required original/mutant assertion failures,
and compiles the real AArch64 performance object. No cumulative Image, module,
runtime, firmware or physical acceptance is produced.

%prep
echo 'fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231  %{SOURCE0}' | sha256sum -c -
%setup -q -n linux-7.3.1
tar -xJf %{SOURCE1}
git init --quiet
test "$(git hash-object drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.c)" = fea173e374648e35b085e51a99661151709d00bf
cp drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.c dpu-original.c
bash dpu-addon/src/display/atomic-perf/apply-checked-state.sh "$PWD"
bash dpu-addon/src/display/atomic-perf/apply-checked-state.sh "$PWD"

%build
set -o pipefail
bash dpu-addon/tests/dpu-checked-state-qualify.sh "$PWD" "$PWD/dpu-original.c" | tee checks.txt
make -s ARCH=arm64 defconfig
scripts/config --enable DRM --enable DRM_MSM --enable DRM_MSM_DPU
make -s ARCH=arm64 olddefconfig prepare
make -s -j2 ARCH=arm64 KCFLAGS=-Werror drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o
readelf -h drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o | grep 'Machine:.*AArch64' | tee -a checks.txt
nm drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o | grep ' T dpu_core_perf_crtc_check$' | tee -a checks.txt
sha256sum drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.c drivers/gpu/drm/msm/disp/dpu1/dpu_core_perf.o .config | tee -a checks.txt
printf 'Independent defconfig object only; full cumulative kernel and physical tests remain open\n' | tee -a checks.txt

%install
install -Dm644 checks.txt %{buildroot}%{_docdir}/%{name}/checks.txt
install -Dm644 dpu-addon/source-commit %{buildroot}%{_docdir}/%{name}/source-commit
install -Dm644 dpu-addon/docs/DPU-CHECKED-STATE.md %{buildroot}%{_docdir}/%{name}/scope.md

%files
%doc %{_docdir}/%{name}/checks.txt
%doc %{_docdir}/%{name}/source-commit
%doc %{_docdir}/%{name}/scope.md

%changelog
* Fri Nov 06 2026 Uke Linux contributors <75160848+MCC45TR@users.noreply.github.com> - 7.3.1-1
- Backport upstream480ba24 with actual-state and real AArch64 object evidence.
SPEC
rpmbuild -bs --define "_sourcedir $output" --define "_srcrpmdir $output" "$output/uke-dpu-perf-check.spec"
