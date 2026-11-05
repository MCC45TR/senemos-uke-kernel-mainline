# Gain243 preparation and admission boundary

5 November 2026. The supported ceiling remains 223. The current 12101 kernel
has no protected provisioning controls and the runtime package is absent.
Source or package qualification does not establish physical speaker safety.

## Read-only preparation tools

`uke-speaker-gain-preflight --json` checks model, running release, the actual
read-only persist mount, installed reader and visible protected controls.
It never reads calibration files, starts a stream or writes mixer values.
It emits a bounded public-metadata report on stdout and exits 2 while blocked.

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
FS19XX as 0x29 and FS1958 as 0x17 in `fsm-dev.h`. `fsm_config_vol()` uses different
encodings for these IDs. Retain the 0x29 register contract; do not transplant
FS1958 or upstream FS2104/5S masks, limits or gain conversions.

Its legacy `fsm_q6afe.c` maps protection-enabled run-in mode to 1 and
protection-disabled mode to 5 for parameter 0x10001fa1. However, the exact
`asoc/codecs/fs19xx/Kbuild` includes only core/fs1958/i2c objects, and the pinned
Forte ACDB contains no 0x10001fa1 record. This is a protocol lead, not proof of
the active Uke AudioReach implementation. No unqualified mode command is added.
The misleadingly named `fsm_afe_get_livedata()` requests calibration parameter
0x10001fab, not live-data 0x10001fa6. Do not expose calibration as VI telemetry or
invent units for that payload. Executable proprietary protection and its limits
remain an explicit dependency.

## Coordinated integration and physical sequence

The camera conversation owns the single cumulative kernel queue. Retain 12101,
touch, geometry, GMU and every other accepted contribution; use the audio
handoff and exact protected source assets. Historical 7700 passed full checks
but is a partial old baseline and must not be installed or independently rebuilt.
The former standalone full producer and kernel-delivery mode are retired.

Before admitting protected DT/graph activation, the coordinator verifies generic
tuning and the actual factory calibration using the offline locked-RAM check.
Calibration remains in its original read-only filesystem. Absent prerequisites
are a blocking integration condition, not a successful protected playback result.
Runtime 0.4 keeps the wire ABI 1 and gain 223; it adds metadata diagnostics only.

After a coordinated kernel passes complete package checks and its existing
recovery/admission process, verify muted fault containment first. Then establish
low-output DSP/VI behavior against the authoritative bounds above. A successful
graph start or a passing readiness parser is insufficient to authorize 243.
Any eventual higher-ceiling implementation needs a separate reviewed kernel
change, default 223, all-four-output health, current fault-generation binding and
immediate revocation on loss. No such activation is included here.

Automatic seamless staging stays enabled. Preserve the user-selected local
rollback-off preference and rollback-enforced package defaults. This contributor
does not change kernel selection, boot state, staging policy or rollback mode.

## Controls-only cumulative layer

`packaging/native/overlay-speaker-controls-only.sh PROFILE AUDIO_COMMIT` is a
source layer for the coordinator. It retains the complete incoming profile
ledger and every old source/config/DT/topology/UCM/firmware byte. It adds code
and one final preparation hook; it does not receive or modify BOOT or the spec.
Use an immutable detached audio tree at the stated exact contribution commit.

The hook excludes the codec portion of 0073 and does not apply 0074, preserving
all legacy amplifier callbacks and stream formats. The existing 223 baseline
stays in use. It compiles the new Uke-only cache/controls with
`UKE_FS19XX_CONTROLS_ONLY`; DT alone cannot admit a graph. All graph callbacks
are inert while inactive, including close/release of legacy graph 40. Optional
cache allocation/crypto/registration failure does not take down legacy audio.
The separate admitted path still fails closed. Cached READY is not protection.

The later admission layer must validate generic/factory data offline, add only
0073's codec hunk and the 0074 format layer, provide both suppliers' complete
protected DT/topology, and remove the controls-only compiler flag. This remains
at 223 and does not satisfy the eight physical gates or enable 243.

### Protected223 cumulative source layer

`overlay-speaker-protected-layer.sh PROFILE AUDIO_COMMIT` prepares that separate
profile on the complete12204 baseline or a compatible later cumulative profile.
It authenticates the89/f05/13/33a contributions, retains all peer bytes, adds
the protected DT include before the original supplier generation, and appends
final preparation after all retained hooks. Only0073's codec hunk is applied.
0074 is retained when already present; otherwise its exact patch is required.
The12204 source rehearsal confirms that its profile omits the format helper;
the admission layer explicitly imports both that helper and its actual PCM test.
The UCM speaker PCM negotiates the admitted formats. Raw capture stays intact.

The original observer gate remains mandatory before and after final preparation.
Final admission requires both supplier overlays, no controls-only compiler flag,
the actual codec safeguard hunk and223 at the final gain writer. The full linked
gate also compares the compiled codec callbacks with their packaged module.
`overlay-speaker-protected-spec.sh SPEC` adds the runtime>=0.4-2 dependency and
the complete protected package check without removing existing spec statements.

The standalone `copr-speaker-protected-check.sh` rehearses complete12204 source,
all24 inherited audio calls, actual safeguard fault/mutant tests, four native
objects and partial links. It emits text receipts only. Its result is separate
from a later cumulative full build, target activation and physical acceptance.
Do not install historical7700, build locally, or submit an independent full
kernel. Before target activation, the coordinator must deliver the runtime
through the supported repository and pass its offline locked-RAM input check.

## Inherited full-package audio checks

Full cumulative 12202 reaches native Image/modules but fails an inherited
APM harness that lacks the newly called helper providers. The controls-only
source/object check did not cover the complete production check list. Apply
`overlay-speaker-legacy-fixtures.sh PROFILE AUDIO_COMMIT` from its exact pinned
detached source after the 89acf61 controls layer. It updates two authenticated
test harnesses and their shared dependency mock; all production bytes and the
preparation hook stay unchanged. Keep the original full `%check` mandatory.

The independent fixture replays the exact 12202 `%prep` and extracts all 24
audio calls from that production spec. Both compiler suites use explicit
`bash -euo pipefail`; inserting the old failing harness into the same dispatcher
must stop it. The coordinator should also run this extracted source-check list
after preparation and before the next Image build, while retaining the final
package checks. Its exact pin/result belongs in the shared audio handoff.

## Meaning of readback

Readiness reports metadata and a software-state snapshot. It does not measure
VI current/voltage, coil temperature, displacement or power. TSEN readback is
an enable-bit check, not a Celsius coil observation. Calibration consistency
does not establish its electrical bounds or the fitted channel/VI identity.

The original 89acf61 state getter can overstate cached RUNNING during normal
quiesce, after the actual guard closes but before release clears the cache.
The read-only observer correction requires a running guard, admitted graph,
live owner and no removal; fault precedence remains mandatory. Otherwise cached
RUNNING is reported as READY, meaning only provisioning is known. This does
not change a cache, DSP operation, codec write, threshold, ABI or gain.

The coordinator applies `overlay-speaker-state-observer.sh PROFILE AUDIO_COMMIT`
from the exact qualified detached source after the controls/fixture layers.
The helper authenticates the original runtime and verifies every byte outside
the one getter. Its actual-function test rejects the old getter and covers288
guard/cache/lifetime combinations; cumulative audio checks and real AArch64
object compilation remain required. Passing these tests supplies no live
transducer measurements and cannot admit243.
