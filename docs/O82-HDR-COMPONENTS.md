# Typed O82 HDR curve and panel-polynomial components

5 November 2026. This source adds bounded component extraction from private HDR
XML and the full 33-coefficient panel polynomial. It is an offline preparation
step for the native integer-table path. Complete mode-policy admission,
metadata/brightness/statistics, output quantization, paired DSPP integration
and physical optical/color acceptance remain open. The production generator
keeps unsupported HDR modes blocked and all display defaults remain unchanged.

The retained Uke vendor reference is
`Xiaomi-Pad-7-Development/android_vendor_xiaomi_uke` at
`6739c8ec275318a156aa3a65f04f54f8dad82926`, file
`proprietary/vendor/lib64/libhdr_tm.so`, SHA256
`42ed49d8b0f79b319107a4ce70cf6ee25ca75888929335b1e1e78702bc9b0f3b`.
Its proprietary provenance and redistribution limits are recorded in the
[HDR source review](O82-HDR-TONEMAP-REVIEW.md). No binary, preset value or
proprietary code is copied, executed or distributed by this implementation.

Static `HDRXml::LoadTmParams` at `0x4c7b0` reads three binary64 rows at offsets
248, 336 and 424. Their exact field order is `c,r,g,b,rr,gg,bb,rg,gb,rb,rgb`.
`panel_mapping_PCC` at `0x51c38` forms squares, pair products and the triple
product with separate binary32 operations, then multiplies and accumulates
binary64 coefficients. The evaluation order is linear terms, `rg/gb/rb`,
squares, `rgb`, then the constant. It converts to binary32 before calling
`Clipping(float,float,float)` with bounds zero and one; the actual GOT/PLT
entry was resolved. The typed evaluator preserves this order and returns
unchanged output on invalid input or arithmetic failure. Early input clipping
or a plain linear matrix would change the defined polynomial. Future client
CTM integration must preserve the factory clipping stage.

The component reader extracts finite typed coefficients, the logarithmic curve
and panel minimum/maximum luminance. It owns the original private XML and names
all remaining root policy fields/attributes, without claiming complete HDR-mode
admission. It rejects duplicate or missing component fields, unknown polynomial
terms, mixed numeric content, numeric entities, namespace substitution,
external declarations, invalid curve order and bounded-resource violations.
No private XML or coefficient is emitted in logs.

Parsing uses the original distribution TinyXML-2 library. The API comparison is
[TinyXML-2 11.0.0](https://github.com/leethomason/tinyxml2/tree/11.0.0),
attributed to Lee Thomason and contributors under the zlib license. No library
source is vendored. The component uses in-memory parsing with entity processing
disabled and rejects unknown declaration nodes. Production JSON decoding is
compiled unchanged into the synthetic bridge fixture, including all three
existing byte-order forms. The existing curve oracle and production utility
self-tests remain in the remote check. The full same-SoC/upstream comparison
and exact hardware-version limits remain those in the linked source inventory;
no board resources or calibration are transplanted.

The check RPM contains only text receipts and a license. COPR qualification
is pending; this source review is not a kernel build, live HDR result or a
physical supplier-variant acceptance claim.
