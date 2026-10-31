# Uke microphone identities

31 October 2026. POCO Pad X1, Fedora Rawhide AArch64, Linux 7.3.1 microphone
development. AMIC1 produces nonzero raw mono recordings on release 10. The
other three inputs, physical aperture locations and simultaneous channel order
remain unqualified. Release 13 adds individual input routes and keeps mono
capture admission. This document does not establish four working microphones.

Keep a stable identity for each analog input across route selection and later
processing. ADC assignments below describe the reviewed individual-input
routes; combined Android use cases can select different ADCs.

| Stable identity | OEM route alias | Individual ADC | Native SWR input | MICBIAS |
|---|---|---|---|---|
| `uke-amic1` | `sidebottom-mic` | 1 | 0 | 1 |
| `uke-amic3` | `top-mic` | 3 | 2 | 3 |
| `uke-amic4` | `back-mic` | 4 | 3 | 3 |
| `uke-amic5` | `sidetop-mic` | 2 | 1 | 4 |

These aliases come from the pinned Uke static mixer overlay, not a controlled
aperture test. Keep physical position, orientation and microphone spacing
unknown until corroborated. Fan ambience provides a capture reference but
does not localize an aperture. The
[input manifest](../manifests/research-microphone-inputs-20261031.json) records
the exact sources, electrical route identities and unverified position fields.

The read-only stock vendor microphone characteristics file matches the pinned
SM8635 common vendor file. It contains duplicate geometry for two declared
microphones and provides no explicit association between `builtin_mic_*` and
AMIC inputs. Its coordinates, response curves and sensitivity values are not
accepted as Uke geometry or installed as processing calibration.

The manufacturer's POCO Pad X1 repair manual shows separate microphone flex
assemblies on pages 28 and 39, with assembly views on pages 44 and 50. These
mechanical views do not label AMIC nets or PCM channels. Retain them as
location research; they cannot complete the electrical-to-aperture mapping.

Each current mono recording has channel zero for the selected input. This
does not define a four-channel order. When simultaneous capture is added,
record the actual PCM index, decimator and analog input together, and verify
that channels are independent. Carry that verified mapping into UCM and
PipeWire metadata without assigning speaker positions to microphone channels.
Do not renumber identities when the screen rotates; apply a separately
documented transform from the fixed body frame to the active display frame.

Before adding Android-derived microphone improvements, qualify the raw input
map, coordinate origin/axes/units and orientation, channel synchronization,
gain and mute behavior. Then assess noise suppression, gain control, echo
cancellation and directional processing individually with their actual ABI,
licensing and calibration dependencies. Preserve a selectable raw capture
path so processing can be compared and disabled. No proprietary DSP preset or
unit calibration is included by this record.

Sources: Uke mixer overlay
[`87f59fc5`](https://github.com/delano-git/android_vendor_xiaomi_uke/blob/87f59fc5c2ef1ee04e494e5258853d36a3346059/proprietary/odm/etc/audio/sku_cliffs/mixer_paths_overlay_static.xml),
common vendor characteristics
[`475e955b`](https://github.com/delano-git/android_vendor_xiaomi_sm8635-common/blob/475e955b3780aee6dd007178e08bf8a231143681/proprietary/vendor/etc/microphone_characteristics.xml),
the [manufacturer's repair manual](https://cdn.shopify.com/s/files/1/0955/8360/0979/files/O82P_POCO_Pad_X1_ERP_Manual.pdf?v=1768881135)
(SHA256 `cb5877be56009060d64a90447f36ccd1cade4a926b633eb89076f4d655202b39`),
and the [Android microphone coordinate contract](https://android.googlesource.com/platform/hardware/interfaces/+/android16-qpr2-release/audio/7.0/types.hal).
