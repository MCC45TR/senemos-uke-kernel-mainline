# Late front EEPROM gate in the cumulative kernel

17 November 2026. Full10/COPR11342132 passed its full build and signed-package
checks, was delivered through DNF, and booted on slot A. Native health accepted
7.3.4-10-unstable with no pending switch or failed systemd units. The preserved
full8/B raw partition and four saved preferences remain unchanged. Full9's
normal boot remained at the POCO logo; the tablet was recovered to accepted8/B
without rewriting either boot partition. The recovery first returned the
default-selector RPM to 8 through DNF; the subsequent normal DNF10 transaction
selected the current full10. Native monitoring is active, with the failed 9 record,
automatic staging and all persistent preferences retained.

The runtime delta is the source33-qualified move of the unchanged read-only
front gate after native MC/GEM tags and FDT capacity restoration. Controller
admission, serial quarantine, exact board validation and failure handling
remain. All four qualified receiver layers and every full9 feature remain in
the parent recipe. No sensor, capture path or additional board power value is
enabled. See [the source finding and qualification](CAMERA-FRONT-STAGE734.md).

The historical full9 gate runs unchanged. The next gate verifies its exact
caller, reverses only its declared activation, and executes the unchanged
qualified source33 layer. Its source seals and qualification must match the
signed proof. Two affected historical source ledgers have complete inverses;
the resulting effective fourteen-file seal is checked through Image linking,
RPM checks and installation. The entire full9 recipe also has a complete
inverse, and the archive projection retains all 3177 regular profile/boot assets
plus three nested historical ledgers. Only declared release metadata and the
two audio identity strings follow the new tuple.

A second pre-link check runs the actual front helper against a small test-only
projection of accepted 8's observed board predicates. Its 42 nodes and 135
properties are explicitly whitelisted, with 13 phandles remapped. It contains
no chosen node, boot arguments, unit identity, memory map, firmware payload or
EEPROM contents. Four compiler/sanitizer modes must admit its 8 KiB read-only
profile, preserve the input and disabled sensor, and repeat without changing
bytes. This fixture is never installed as a runtime DT.

The native GENI8 adapter and at24 read-only NVMEM provider now bind on the
tablet. Two bounded 8192-byte reads were byte-identical and contained programmed
data; both the adapter and EEPROM returned to runtime suspend after each read.
The NVMEM file is root-only mode 0400. Fitted bytes remain in private root-only
files and are absent from source, COPR inputs and this report.

GPI aborted-transfer errors occurred during initial access and read retries.
The complete reads succeeded, but the transient cause is not established;
binding and repeatability are not evidence of an error-free bus or a physical
voltage measurement. The controller remains ready, firmware-managed and idle.
See the [bounded device result](../manifests/camera-full73410-device-20261117.json).

There is still no sensor/capture graph or completed camera frame.
Fitted sensor identity/address, complete sensor power and lane wiring,
interconnect ownership, aggregate CAMSS, private calibration, rear focus and
both cameras' full capabilities remain open.
