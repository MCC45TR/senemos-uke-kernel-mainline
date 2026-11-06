# Compose the private audio DMA supplier after the native overlay

6 November 2026. Full12212/COPR11270769 boots in A with preserved B12211,
automatic staging and local rollbackoff. Six installed RPMs verify, but no
ALSA card appears. The built-in provider registers without a bound device;
`/audio-config-memory` is absent from the live tree and APM remains deferred.
This supersedes any implication that native objects or Image linkage proved
device DMA activation. No protected stream was attempted on this boot.

Exact12212 source7b3b8a80 places `uke_audio_config_graph(output)` at the end of
`uke_abl_transform`. The existing native entry applies the selected display
and audio overlay afterward through `uke_abl_native_select`. The protected
marker is absent at the early call, so the legacy no-op succeeds; the later
protected APM then waits for the missing supplier. The standalone helper
fixture did not exercise this production ordering.

The proposed next delta removes only that early call and inserts the same
helper after successful native selection, before accepting the private tree.
Native selection returns a packed FDT, so restore the existing buffer's full
capacity, compose the supplier, then pack again. Existing refusal of a partial
graph remains mandatory. A reverse patch must reproduce the exact original
source. No DMA/transport/protection bytes, SID, clock, regulator, firmware,
private calibration or policy change is proposed.

A new COPR fixture extracts the actual production `uke_abl_prepare_fdt` entry.
Controlled base/native callbacks apply a real libfdt overlay and pack at the
same phase boundaries; the fitted supplier helper is unchanged. The fixture
requires the final supplier, unchanged frontend IOMMU bytes and immutable input,
and tests foreign/legacy handling and rejected graph publication. The original
entry must reproduce the missing supplier. A removed-capacity mutant must fail.
GCC/Clang plain and sanitizer modes plus actual AArch64 objects remain required.
This validates the specific entry boundary, not complete DPU behavior or
physical audio. No local native compilation is permitted.

The candidate extends exact complete12212/SRPM80b8340e, including qualified
FastRPC DMA admission and all previous audio/camera/input/power features.
A fresh unique source check and its same-source trusted receipt precede any
full12213 reservation. Preserve the current slot, automatic staging, rollback
preference, recovery components and temporary exact-chat continuation.

Source comparison: exact project12212 native entry, GPL-2.0-only; existing
native-display patch and `src/display/uke-abl-native.h`, unchanged attribution;
Linux7.3.1/libfdt `fdt_open_into`, `fdt_pack` and `fdt_overlay_apply`. Exact Uke
OEM and shared-IP sources remain the basis of the unchanged audio resources.
No applicable donor implements this project-specific staging wrapper, and no
other-board value is imported. Source/build evidence and device acceptance
remain separate.

Check25/11271046 fails164s after retained backend/lease/DT/startup gates and
exact forward/inverse patch application pass. The new extractor included a
forward declaration and stopped at an unrelated first function. Check26
requires the complete definition line and excludes semicolon declarations.
The production entry patch is unchanged. No new entry/native-object result or
full12213 reservation is established by check25.
