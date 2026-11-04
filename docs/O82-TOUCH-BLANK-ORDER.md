# Uke touch preparation before panel OFF

4 November 2026. Running11003 records setting0x11 ACK timeouts before refusing
gesture retention. Its complete physical cause is not established. This source
candidate addresses a separate, attributable lifecycle ordering difference.

The [retained Uke OEM modules](https://github.com/vember31/android_device_xiaomi_uke-kernel/tree/9bb7c4331be7205fabf5427b5654555763304d20) share
the same6.1.68 Android build and GPL attribution. Static inspection, without
loading either module, finds the TDDI early-blank branch of
`xiaomi_drm_panel_notifier_callback`: it flushes pending work and synchronously
invokes touch suspend while early_trigger is set. The NT36532 suspend path calls
the0x11/0x1b ACKed setters before pen configuration and final0x13. Module SHA256:
`7003b341321183214e8fbf35cbe05143c4fa26ec3edf10c366641ff96106e076`
(xiaomi_touch) and
`cee722d7baf86ecadb8992038781f48ac6098c54964c31c26113420695e9eca8`
(nt36532_touch). Native transport bytes, mandatory ACKs and bounded retries
already agree with that module; extra retries or ignored errors are not justified.

The [Uke display source44275c4](https://github.com/MiCode/vendor_opensource_display-drivers/blob/44275c404a677d9d9e5230fedd1af2ef02fc7b9a/msm/sde/sde_kms.c)
calls `_sde_kms_drm_check_dpms(state, true)` during prepare_commit, before
commit; complete_commit sends the later notification. Its sde_kms.c SHA256 is
`b0c49bbb2a98f4eaf1489f6e9096b1b29691161760b6b0957ad894e8ede87fec`.
The same source's [msm_atomic.c](https://github.com/MiCode/vendor_opensource_display-drivers/blob/44275c404a677d9d9e5230fedd1af2ef02fc7b9a/msm/msm_atomic.c)
calls prepare_commit before modeset_disables; its SHA256 is
`0fd9f717b268ad5c8f1fa71567e018e1bad76afcd0c18deb1db9165c64e04516`.
Both C files match the pinned primary remote bytes. The display code retains
its GPL-2.0-only attribution; no OEM code is copied into the small native patch.
[Uke display DT4a3e1c3](https://github.com/MiCode/vendor_qcom_proprietary_display-devicetree/blob/4a3e1c391130237c5e8c2b250d1c94f3e25b9b11/display/dsi-panel-o81-o82-dualdsi-dsc-lcd-video-qcomcommon.dtsi) supplies the OFF
sequence0x28,0x10,0x4f with its existing delays. The OEM framework source and
shared P81/P82 drivers are comparison inputs; their current C sources are not
claimed byte-identical to the retained OEM modules. Existing OnePlus/Lenovo
and upstream Novatek comparisons in [the protocol record](NT36532-PROTOCOL.md)
do not establish the Uke TDDI ordering.

The native panel requests touch retention after sending OFF. The candidate
requests it while a prepared panel and all its supplies remain available, then
sends the unchanged OFF sequence. Retention is published only if both touch
and OFF succeed. OFF failure/short write still invokes the existing release,
reset and supply cleanup. Removed or partially prepared panels cannot acquire
retention. Supply values, firmware, commands, delays, reset ownership and
admission policies are unchanged. This is a sequencing candidate, not proof
that early blank resolves every observed touch-return or desktop stall.

`copr-o82-touch-order-check.sh` reuses the existing `uke-o82-kms-check` fixture
family. It imports the exact qualified11003 source RPM, preserving every
original source and its complete preparation. A small patch extends that
parent's actual callback fixture rather than replacing its other checks.
The original callback must fail the new early-blank assertion. The candidate
must pass both suppliers and all seven modes, repeated retention/resume/remove,
OFF failure and short write, touch refusal and partial cleanup under GCC/Clang
UBSan and ASan. The existing real protocol regressions also check the final
ACK-byte diagnostic from59d6c42. Only text receipts are packaged; do not install
this fixture on the tablet. All compilation remains in COPR.

COPR11260818 succeeds from27471abc9cf4ed25011fb26383ccf35f8505aa43 as fixture
7.3.1-13. The actual original11003 callback reaches the required assertion134;
the corrected callback passes the complete two-supplier/seven-mode lifecycle
and fault matrix under both compiler/sanitizer pairs. Retained gesture negative
controls and the full protocol matrix also pass. Fixture12 first exposed a
per-powered-cycle ON packet counter missing from the expanded test adapter;
13 resets that adapter counter at the explicit resume boundary. The production
patch and all ordering, recurrence and fault assertions remain unchanged.
An earlier source-worker dist assertion failed before publishing a source RPM.

Final native compressed log SHA256:
`5a954e8f8398f71ab4026e0267238783b2bf428eeb248985f97083449af63320`.
The signed text-only fixture RPM SHA256 is
`9725812be5641e9afe1f39dfa4e6086193b4782d327f369ce75ab751c3bf4284`;
its exact source commit and empty install scripts were checked. No fixture is
installed on Uke. Published fixture13 is immutable. A combined native
kernel/module build, matching signed DNF delivery and physical off/on,
suspend/wake and long-run input/display acceptance remain separate gates under
the single kernel coordinator.
