# Front camera identification prerequisite

17 November 2026. Full9/COPR11341382 built and passed signed-package checks,
but its first normal boot stayed at the POCO logo throughout a 180-second
optical observation. No Linux console, SSH identity or native health acceptance
was obtained. The accepted full8/B boot partition was verified unchanged before
the attempt and remains the recovery baseline. Its native
CAMCC controller passed two normal boots and released to runtime suspend.
The isolated-controller condition that held back the front EEPROM has been met.

The late overlay enables the already qualified GENI8/read-only EEPROM FDT
converter after controller admission and general QUP quarantine. Its complete
source inverse is checked. The existing helper validates the exact Uke bus,
GCC clock, interrupt, DMA route, IOMMU, interconnect, pinctrl, L20B and EEPROM
preimage before mutation. It retains the sensor and overlapping serial
personalities disabled. It introduces no sensor address or power sequence.

The EEPROM profile uses the inherited address 0x51, an 8 KiB/16-bit-address
protocol and read-only NVMEM with a scoped 1.8 V request. The shared provider's
range remains unchanged. This is a protocol description, not identification
of a fitted manufacturer or calibration layout. Binding can issue an initial
one-byte read. Any fitted data is private and must remain read-only; no raw
calibration or unit identifier enters a public source or COPR input.

Linux 7.3.4 GENI checks the serial-engine protocol and selects FIFO or GPI
according to hardware capability. GPI's serial-engine ID is separate from its
allocated ring-instance ID: `gpi_find_avail_gpii()` chooses an allowed free
instance. The front route's SEID zero therefore does not require enabling
GPI instance zero. The existing 0x1e instance mask is retained. Missing firmware
or unavailable channels must be reported by the native driver; no substitute
firmware, forced mode or arbitrary register access is introduced.

The cumulative candidate retains source27 lite VFE, source30 scoped PHY power,
source31 CSID IRQ and source32 stream lifecycle layers, with their original
source seals, proof and tests. It preserves the complete full8 recipe through
a whole-file inverse and retains the original profile and boot assets except
the declared release tuple. Those archives describe the historical base;
the separate late-layer qualification describes effective EEPROM admission.

The new COPR gate runs the actual FDT helper in four compiler/sanitizer modes,
retains malformed-graph refusals, checks controller/quarantine/front order and
builds the real ARM64 caller. The final Image must contain the front EEPROM
marker, with the linked objects and effective sources sealed through install
and package checks. Two affected historical ledger entries have complete
inverses; source/Image/object changes and missing seals are refused.

Native adapter and EEPROM binding, idle release and any private module-data
interpretation still require tablet observation. The fitted front sensor ID,
address, complete power sequence and lane map remain unresolved. HF interconnect
ownership/error handling, aggregate CAMSS resources and physical buffers are
also open. Original Fedora media applications remain in use. Both complete
cameras, private read-only calibration and rear focus remain the broader goal.

Primary references are the existing Uke source inventory and the pinned GPL
Linux 7.3.4 `i2c-qcom-geni.c`, `gpi.c` and GPI binding under
`referances/front-geni734-20261117`. No donor scripts or closed camera code are
executed or analyzed by this candidate.

The source review after this failure found an entry-phase mismatch. The front
helper validates two-argument GEM and MC interconnect tuples. The early full9
call runs before native selection, while that selection later adds the tags
through the existing bandwidth-monitor converters. The previous synthetic
fixture supplied those final tuples at construction and did not exercise this
phase boundary. The source mismatch is established; the inaccessible boot has
not supplied a firmware or kernel log proving its exact stopping instruction.
See [the late-entry correction](CAMERA-FRONT-STAGE734.md). No new device retry
or camera acceptance is implied by that source work.
