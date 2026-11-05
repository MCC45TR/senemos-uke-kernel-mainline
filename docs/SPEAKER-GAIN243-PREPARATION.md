# Gain243 preparation and admission boundary

5 November 2026. The supported ceiling remains223. The current12101 kernel
has no protected provisioning controls and the runtime package is absent.
Source or package qualification does not establish physical speaker safety.

## Read-only preparation tools

`uke-speaker-gain-preflight --json` checks model, running release, the actual
read-only persist mount, installed reader and visible protected controls.
It never reads calibration files, starts a stream or writes mixer values.
It emits a bounded public-metadata report on stdout and exits2 while blocked.

`uke-speaker-runtime --gain-readiness` authenticates both kernel controls and
reads their state through an ALSA read-only handle. READY/PREPARED/RUNNING are
reported separately from physical evidence. Every state, including RUNNING,
continues to deny243. Missing, spoofed or malformed interfaces remain blocked.
This mode never opens generic tuning or private calibration. Combined operation
flags are refused; it cannot be combined with loading or calibration checking.

The report deliberately has no approval-file input, force switch or gain writer.
Eight evidence classes remain unverified until separately established:

| Evidence | Required result before any higher-gain patch |
| --- | --- |
| DSP protection mode | Matching installed DSP implementation and accepted active protection configuration, including its limiting path |
| Electrical calibration and binding | All four factory records electrically valid and bound to the fitted physical outputs; inspect only in locked RAM from the original read-only source |
| Gain transfer function | Exact0x29 amplifier gain encoding and its voltage/dB relationship;243 is an index, not a percentage |
| VI feedback | Four-channel physical identity, units, scale, polarity, freshness and continuity proven at bounded low output |
| Power limit | Authoritative fitted-transducer bounds and effective limiting before exceeding those bounds |
| Coil temperature | Valid coil estimator/measurement and limiting; TSEN enable or package temperature is insufficient |
| Excursion | Authoritative fitted-transducer displacement bounds and effective containment |
| Fault response | Validated worst-case containment deadline for sensor/VI loss, DSP restart, I2C failure and stream teardown;250ms polling is diagnostic |

Do not find unknown limits by overheating, clipping or overdriving the speakers.
Higher-level testing remains below the retained ceiling. Missing feedback must
mute before any gain experiment. Do not inject real shorts or destructive loads.
Record qualified conclusions; keep unit calibration, raw unit measurements and
unit hashes out of source, RPMs, COPR and public logs.

## Exact source findings

MiCode audio commit `8eb0eccbc4027ae4a4987e4bced03a4381039714` identifies
FS19XX as0x29 and FS1958 as0x17 in `fsm-dev.h`. `fsm_config_vol()` uses different
encodings for these IDs. Retain the0x29 register contract; do not transplant
FS1958 or upstream FS2104/5S masks, limits or gain conversions.

Its legacy `fsm_q6afe.c` maps protection-enabled run-in mode to1 and
protection-disabled mode to5 for parameter0x10001fa1. However, the exact
`asoc/codecs/fs19xx/Kbuild` includes only core/fs1958/i2c objects, and the pinned
Forte ACDB contains no0x10001fa1 record. This is a protocol lead, not proof of
the active Uke AudioReach implementation. No unqualified mode command is added.
The misleadingly named `fsm_afe_get_livedata()` requests calibration parameter
0x10001fab, not live-data0x10001fa6. Do not expose calibration as VI telemetry or
invent units for that payload. Executable proprietary protection and its limits
remain an explicit dependency.

## Coordinated integration and physical sequence

The camera conversation owns the single cumulative kernel queue. Retain12101,
touch, geometry, GMU and every other accepted contribution; use the audio
handoff and exact protected source assets. Historical7700 passed full checks
but is a partial old baseline and must not be installed or independently rebuilt.
The former standalone full producer and kernel-delivery mode are retired.

Before admitting protected DT/graph activation, the coordinator verifies generic
tuning and the actual factory calibration using the offline locked-RAM check.
Calibration remains in its original read-only filesystem. Absent prerequisites
are a blocking integration condition, not a successful protected playback result.
Runtime0.4 keeps the wire ABI1 and gain223; it adds metadata diagnostics only.

After a coordinated kernel passes complete package checks and its existing
recovery/admission process, verify muted fault containment first. Then establish
low-output DSP/VI behavior against the authoritative bounds above. A successful
graph start or a passing readiness parser is insufficient to authorize243.
Any eventual higher-ceiling implementation needs a separate reviewed kernel
change, default223, all-four-output health, current fault-generation binding and
immediate revocation on loss. No such activation is included here.

Automatic seamless staging stays enabled. Preserve the user-selected local
rollback-off preference and rollback-enforced package defaults. This contributor
does not change kernel selection, boot state, staging policy or rollback mode.
