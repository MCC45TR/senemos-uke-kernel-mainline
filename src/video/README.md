# Inactive SM7675 Iris33 source candidate

Date: **20 October 2026**. Base: **7.2.11-11**, source `3b9b61a`.
The complete Iris composite object and VIDEOCC object compile for AArch64 with
Clang **23.1.3**, `KCFLAGS=-Werror`. The actual two-pipe lifecycle fixture passes
on the host. These are object/fixture results, without a full kernel, RPM,
firmware authentication or tablet decode result.

Three project patches from candidate `e344c7b` and four integration fixes
are retained outside the active series. The native clock header is also
referenced by its binding. The
[manifest](../../manifests/iris-source-candidate-20261020.json) records exact
base files, patch hashes, source attribution and remaining admission gaps.
There is no Iris OF match, DT enablement, release change or firmware payload.
The stock `qcom,cliffs-videocc` ABI remains unmatched; its numeric clock/reset
IDs must not be used with the native provider. Existing platform operations
retain their paths.

## Reproduce on a disposable prepared source tree

Prepare the signed kernel11 RPM inputs through the complete package `%prep`
first. Keep this candidate separate from the accepted build and boot tuple.
The source directory must have its own Git root; otherwise Git can skip paths
under a parent worktree. Run these host commands from this repository:

```bash
candidate=$PWD
source_dir=$(realpath /path/to/disposable/linux-7.2.11)
test "$(git -C "$source_dir" rev-parse --show-toplevel)" = "$source_dir"
make validate-video
(cd "$source_dir"; sha256sum -c <(jq -r \
  '.baseline_files[] | .sha256 + "  " + .path' \
  "$candidate/manifests/iris-source-candidate-20261020.json"))
for patch in "$candidate"/patches/video/*.patch; do
  git -C "$source_dir" apply --check "$patch" || exit 1
  git -C "$source_dir" apply "$patch" || exit 1
done
make test-video video_source="$source_dir"
```

The C++ fixture compiles the actual preset header and extracted quiesce
function. It checks exact masked writes, successful bridge reset order, both
pipe-idle faults, permanent LPI denial and each sideband busy bit. Failed
quiesce never reaches the helper's bridge reset, and retries stay bounded.
This does not qualify the outer driver's forced shutdown or PM recovery.

The boot-status fixture first reproduces a false success in the unmodified
common boot function. Patch0004 checks the existing error mask before ready,
returns `-EIO` for firmware errors and keeps polling pending-only status within
the existing timeout. Tests cover immediate/delayed/last-attempt ready, no
response, pending-only timeout, every error-mask bit and ready/error mixtures.
The initial/resume callers already unwind on a nonzero boot result; their
cleanup paths are retained. Patch0005 also checks OPP errors before enabling
interrupts, preserves resume errno and invalidates a failed interconnect cache
so subsequent requests retry. Actual-function tests cover each resource stage.

Patch0006 connects the exact Cliffs clock voltage ceilings to the existing
regulator aggregator. PLLs vote MXC; MVS0/1 vote MMCX and MXC. The native
SM7675 binding requires both regulator supplies and rejects competing power
domains/required OPPs. Other platforms keep their domain contract. Iris skips
an empty OPP-domain list rather than attaching every domain again. The
2000 MHz admitted PLL ceiling covers these clock tables; the OEM 2300 MHz
HIGH_L1 entry is outside the admitted HIGH-class supply and is not exposed.
Actual helper fixtures cover regulator acquisition, PLL/proxy failures,
cleanup and retry; the synthetic binding accepts the regulator node and
rejects five missing/mixed/foreign cases. Firmware mapping remains incomplete.

For the separate AArch64 object check, use the normal LLVM kernel toolchain,
an isolated ARM64 defconfig with `VIDEO_QCOM_IRIS=m` and `SM_VIDEOCC_8550=y`,
and build `drivers/media/platform/qcom/iris/` plus
`drivers/clk/qcom/videocc-sm8550.o` with `KCFLAGS=-Werror`. It does not produce
an installable module bundle or boot image.

## PAS ownership follow-up, 21 October 2026

The seventh inactive patch retains possible secure-world ownership from the
MDT load attempt until PAS shutdown succeeds. Failed load/auth/protection
cleanup preserves its original errno. A failed stop keeps DMA queues and power
votes, blocks automatic restart and refuses PM transitions until cleanup can
complete. The actual-function GCC/Clang fixture covers all startup stages,
failed-stop retry, response timeout, PM accounting and recovery.

The original deinit function is independently reproduced freeing queues after
a failed PAS stop. Current upstream `f47d2236` retains that core path, although
its firmware detection and PAS API have advanced. This patch retains the
7.2.11 SCM API. Forced platform removal and delayed-work teardown still require
separate lifetime work; logging a removal failure cannot veto driver detach.
No MMIO mapping, split context-bank admission or physical result follows from
these host checks.

## Activation remains blocked

The native provider/consumer conversion must resolve regulator/genpd/OPP
ownership, controller retention, the extra VCODEC reset and PM error handling.
Firmware mmap/device regions, high device IOVAs and the distinct non-pixel
`0x1940` / pixel `0x1947` context banks require a complete lifetime/ownership
contract. Do not widen the DMA mask or copy Palawan's four-pipe table as a
substitute. The local firmware's identity does not establish PAS trust or
redistribution permission; no blob is included here.

After those prerequisites, qualify bounded firmware start/stop and H.264 frame
equivalence, drain/EOS, resolution changes, corrupt input and teardown on the
tablet. Then test original Fedora GStreamer/VA-API/browser consumers separately.
AV1, encoding, zero-copy and energy savings remain unqualified; FastCV/CDSP
stays disabled. See the canonical
[Iris continuation report](https://github.com/MCC45TR/uke-linux-docs/blob/main/docs/testing/UKE-IRIS-FIRMWARE-2026-10-20.md).
