# OV13B10 Device Tree prerequisite

Date: 20 October 2026. Linux 7.2.11; source candidate only.

Two inactive patches add a generic OV13B10 binding and OF match table. Upstream
already implements generic fwnodes, a 19.2 MHz clock, three supplies and two/four
CSI-2 lanes at 560 MHz, but currently exports only ACPI matching. Existing
register tables, power sequencing and ACPI behavior are unchanged.

The complete driver compiles as an AArch64 object with Clang23 and `-Werror`.
The kernel's real `dt_binding_check` passes. Actual DT validation accepts two
and four lanes and rejects eight missing-resource, invalid-lane/frequency and
unknown-property cases. Patch application is checked against fresh copies of
the exact preimage and compared byte-for-byte with the compiled source.

These files are outside the active patch series. No sensor node, board power
sequence, CSI route, CAMSS platform or calibration is enabled. The Uke OEM DT's
rear OV13B10 comment does not prove the fitted module; front identity remains
unresolved. The generic example is not Uke wiring. Native RAW capture requires
the exact provider, CCI, CSIPHY/CSID/IFE, IOMMU and endpoint graph first.

Host-only checks:

```sh
bash tests/camera-source-contract.sh /path/to/pristine/prepared/linux
bash tests/camera-binding-contract.sh /path/to/patched/linux /path/to/schema-output
```

Binding validation uses the existing isolated SDK's original dt-schema2026.09,
Clang23.1.3, yamllint1.38.0, ply3.11 and GitPython3.2.1. Their upstream Python
helpers run only on the host to validate Linux schemas; they are not project
scripts or tablet/initramfs dependencies. No camera package, kernel image,
firmware startup or physical capture is established by these checks.
