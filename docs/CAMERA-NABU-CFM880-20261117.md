# Pad 5 camera source comparison

17 November 2026. Source32/COPR11341240 passed in 542 seconds; its signed
proof and actual source match the
[qualification record](../manifests/csid-stream734-qualification-20261117.json).
The relevant contributor is Cheng Fangming, **CFM880**.
The Uke maintainer's `nabu-camera` repository credits his original camera
implementation, and GitHub's contributor records include CFM880 in both that
repository and `nabu-linux-kernel`. The reviewed source is
[CFM880/nabu-camera at 3f341b7d](https://github.com/CFM880/nabu-camera/tree/3f341b7d1249536067693ec28cb44f52a7795250).
Its README describes experimental support, rather than complete qualification
on Uke or an independently verified OEM feature set.

The repository combines SM8150 CAMSS/CCI, CSIPHY, CSID gen2 and VFE17x with
OV8856 front and OV13B10 rear drivers. A CN3927 VCM driver exposes standard
`V4L2_CID_FOCUS_ABSOLUTE`. Its C++ autofocus prototype measures image sharpness,
performs coarse and fine focus searches, and supports a selected image region.
The userspace path uses libcamera, GStreamer and standard V4L2 controls.

| Source component | Relevance to Uke |
| --- | --- |
| Common CSID stream callback | Same callback and hardware-operation contract; narrow source32 candidate |
| Gen2 CSID and VFE17x registers | Different receive hardware; retain Uke gen3/860-to-880 evidence |
| OV8856 front sensor | Different from Uke's OV08D10 candidate; no fitted identity inferred |
| OV13B10 and CN3927 | Useful driver/interface comparison; fitted Uke model, actuator, power and calibration still require evidence |
| Board DT | Nabu-specific GPIO, rails, clock, CCI, lanes, IRQ and SMMU values; not imported |
| VDIG always-on workaround | Diagnostic rail-retention change; not imported into Uke's demand-based lifecycle |
| Simple IPA tuning | Repository README identifies closed QTI tuning recovery; not admitted under the OSS-only camera scope |
| Snapshot patch and install scripts | Not imported; preserve original Fedora applications and signed DNF delivery |

Uke's selected front bus is GENI8 I2C, rather than the donor's CCI path.
The fitted address is still unresolved; neither a donor address nor the generic
inherited sensor-node `reg` establishes that address. Linux 7.3.4 OV13B10 also
has two- and four-lane support, while this donor overlay selects four lanes.
Replacing the driver wholesale would discard newer native functionality.
Existing Uke OV13B10 OF-match and OV08D10 source patches retain their separate
qualification and activation status; this comparison does not enable them.

## Shared stream lifecycle correction

The original Linux 7.3.4 `csid_set_stream()` calls `configure_stream()` only
when `need_vc_update` is set. The first start clears that flag. With unchanged
links, the next stop can skip the hardware stop, and the next start can skip
configuration after a format change. The gen3 operation actually starts and
stops RDI paths, so caching the entire operation is inappropriate.

CFM880 calls the operation on every start and stop, preserving the existing
control setup, link checks and errors. The proposed Uke callback is byte
identical to that pinned donor callback. This imports no board values or
register definitions. The separate
[upstream proposal by Bryan O'Donoghue](https://lists.openwall.net/linux-kernel/2026/10/05/1531)
describes the same failure and also removes the obsolete flag and assignments.
The narrow candidate retains those compatibility fields; it does not claim
that the upstream proposal is merged.

The donor's `SOURCE.md` records a postmarketOS SM8150 base at
`5181e1358ddd6ea8028e841d928942373e6aebc8` and a camera-reopen/runtime-suspend
fix. Its broader runtime-PM and partial-pipeline error changes are not copied
wholesale over the different Linux 7.3.4 lifecycle.

## Qualification boundary

Source32 retains every source31 input and the complete prior RPM recipe,
verified by a whole-file inverse. The new test composes the actual common
callback with the actual gen3 dispatcher. It requires two original failure
controls, four GCC/Clang plain/sanitized modes, 2048 fixed-link cycles per mode,
48 unchanged entry/refusal cases, five semantic mutants and two real ARM64
objects. The cycles cover repeated stop, changed formats and modeled power
transitions. All of these checks passed. The actual SRPM has 29 members and
retains all 27 immutable parent inputs; the complete parent recipe inverse,
new layer, donor callback and packaged result hashes match. Both proof
signatures verify against the trusted COPR key. These are source/model/object
checks, not a hardware suspend or capture test.

Accepted full8/B remains installed. Source27 lite VFE, source30 scoped PHY
power and source31 CSID IRQ changes remain cumulative. No sensor graph is
activated by this change. HF interconnect ownership and error handling,
aggregate resources, fitted sensor identity/address/power/lanes, both cameras'
full capabilities, private read-only calibration and rear focus remain open.

Original kernel notices and per-file licenses remain intact. Thirty-one
selected reference files are pinned by Git blob hashes under
`referances/nabu-cfm880-20261117/source.json`; donor scripts are not executed.
Only the GPL common CSID file is included as the source32 comparison oracle.
