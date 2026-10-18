# Uke standard charging-control source — 18 October 2026

Environment: isolated source work based on joint kernel
`f429992feb638e7dffc0142ecb77c6b1a86fc16e`. No patch-application check, compiler,
fixture, package, boot, firmware query or hardware operation was run here.

`patches/7.2.10/0067-uke-battmgr-qualified-control.patch` adds Uke-only standard
power-supply thresholds and optional positive constant-current control. Both
new EXPERT options default to n; no build configuration enables them. The new
patch follows 0064 in this isolated queue; the coordinator owns composition with
USB-owned 0065/0066 and any later queue. No USB, DT, PHY or display file changed.

The exact local OEM pin is MiCode uke-v-oss
`5712080a4b0c0b1a879e6d145c601c649ddaddfd`,
`drivers/power/supply/qti_battery_charger.c` (GPL-2.0-only, The Linux Foundation /
Qualcomm Innovation Center). Unlike ambiguous thermal wire10, the distinct
`BATT_CONSTANT_CURRENT` wire12 has a `CONSTANT_CHARGE_CURRENT` SET route through
`battery_psy_set_fcc()`. The wrapper returns zero regardless of its callee error;
this backend requires transport/remote success and exact GET readback. Its
positive-uA semantics still require active firmware/pack evidence. No negative
or UINT_MAX reset sentinel is exposed. EN/start/end use wire25/26/27; opcode0x48
carries target/delta. An opaque ACK never qualifies an applied target.

Compared same-SoC OnePlus `fc892483f1d61f245924681eb5abd563564d9cba` (same file),
shared-protocol Peridot `2ed9eadbecae21ef51134e556951e7305ba65f88` and local Linux
snapshot `4056b3c9d3c92ea45955641dbafeb9b960e146ef` (`qcom_battmgr.c`). Existing
upstream/shared files retain Linaro/Qualcomm attribution. No board-specific
limits, thermal tables or donor scripts were copied or executed. The workspace
SM7675 inventory and donor policy remain applicable. This is not a claim about
an unqueried current upstream HEAD.

The typed auxiliary-device admission ABI is documented inside the patch at
`Documentation/ABI/testing/sysfs-driver-qcom-battmgr-uke-control`. It binds root
permission to a referenced TGID, profile digest, exact local driver/firmware/source
epochs, reviewed time and <=30 second CLOCK_BOOTTIME lease. Suspend/PDR invalidates
older reviews. The companion native helper verifies per-boot artifact evidence;
the kernel does not authenticate a remote firmware identity or inspect a proof
file. Root is the evidence admission authority.

Threshold and current SETs use fresh health/presence/V/I/T/source guards, the
existing request mutex and mandatory firmware readback. Current has separate
profile/band/source-budget admission. It never writes voltage or negotiates
PD/QC/PPS/EPR. Firmware owns CV and autonomous charging protections. A USB budget
is not a battery FCC limit; no conversion or numerical Uke limit is invented.
Readback does not prove physical effect. Lease expiry cannot electrically cut
charging or undo the last firmware setting.

Original KDE uses standard `charge_control_start_threshold` /
`charge_control_end_threshold`. Standard getters expose only verified caches
under an admitted standard-client lease, otherwise ENODATA. The two KDE writes
are independently guarded and can partially apply; the native pair API does not
claim remote atomicity either. No KDE package is forked or rebuilt. Desktop
service activation can restore saved thresholds and needs a separate admitted
stage. The native observer's property allowlist/D-Bus remains read-only.

Deferred coordinator checks:

1. Compose exact sources; inspect patch application and compile options both
   off and on against the selected kernel. Preserve stock firmware, Android A,
   Linux boot_b, matched modules and rollback artifacts.
2. Run existing battery protocol/coordinator/readiness fixtures and new
   `bash tests/battery-control-transport.sh PREPARED_KERNEL`. The latter enables
   only synthetic host admission, exercises actual request/RX functions and
   checks denied raw/zero/reset writes, lifecycle invalidation, exact/invalid
   ACK envelopes and no replay. It does not exercise all sysfs/profile logic.
3. Run companion runtime fake-I/O/profile fixtures, original desktop integration
   and package/activation checks. Add focused fault injection for guard/GET/SET
   ordering and each failure boundary before permitting controls.
4. Use the central staged PC-USB/VRR plan; qualify exact active firmware, units,
   source budget, protections, readback and physical effects before adapters.
   No F5 high-power qualification or hardware-risk closure follows from source.
