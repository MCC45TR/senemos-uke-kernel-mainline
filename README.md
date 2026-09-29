# Senemos Uke mainline kernel

Develop senemos-uke-kernel-mainline for Xiaomi Pad 7 (SM7675), starting from Linux 7.2.8 and a separately reproduced Linux 6.12 donor.

**Status: preparation only.** No project image has been built or tested on a Pad 7. This repository is a component of [Uke Linux](https://github.com/MCC45TR/uke-linux); see its [100-step plan](https://github.com/MCC45TR/uke-linux/blob/main/PLAN.md) and [hardware ledger](https://github.com/MCC45TR/uke-linux/blob/main/DEVICE-STATUS.md).

## Next implementation work

Archive the remaining source sets, compile the unchanged baseline and reproduce the donor before splitting and forward-porting its patches.

## Layout

- `src/`: project code; large active upstream checkouts use ignored `src/upstream/`.
- `configs/`, `patches/`, `scripts/`, `tests/`: reviewed configuration, attributed patches, host helpers and test definitions.
- `docs/`, `manifests/`, `reports/`: architecture, source identities and reviewed evidence.
- `referances/`: local unmodified reference clones and Git bundles; see its README.
- `build/`, `artifacts/`: local generated output, excluded from source publication.

New native tablet tools use C++. Host automation prefers Bash; Python must never ship to or run on the tablet. Upstream kernel/firmware languages remain unchanged. Read [AGENTS.md](AGENTS.md) before contributing.

The source plan lists component-relative reference paths. The workspace owns acquisition and archive verification through `scripts/sources.sh`; clone the workspace with submodules to use that orchestration. Reference history and licensing are preserved independently of this repository. The MIT license covers original preparation material, not imported upstream code.
