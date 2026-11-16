# Apply O82 ABM changes without a panel power modeset

16 November 2026. On accepted7.3.4-2, changing KDE's adaptive backlight
modulation causes a brief black screen. Patch0070 marks an ABM change as
`connectors_changed`, and applies CABC only from panel prepare. This forces
the complete power modeset for a level change.

The prepared late source layer removes that invalidation and applies the
original bounded CABC command from the serialized MSM atomic commit while
the powered dual-DSI video path is active. A registered callback retains the
existing board, fitted-panel, ownership and last-callback lifetime checks.
Removal and shutdown unregister before releasing panel resources. Both known
O82 variants retain their exact CABC mappings.

The panel caches its last successful level. A failed update attempts one
restore; a failed restore refuses more ABM writes until a normal panel
prepare. It starts no reset, blanking, polling or recovery loop. A separate
ABM mutex lets the existing first-frame worker finish its command groups
before publishing a deferred level, without taking the panel mutex that
disable holds during work cancellation. Combined timing/ABM transactions
retain the ordinary full modeset rather than changing the proven DFPS path.

Six exact7342 parent files and postimages are pinned. A complete inverse
preserves the accepted early touch-retention change; the generic checkout's
older panel source must not replace this source.

COPR11333196, source7a998264, passed the complete retained native13 checks
and four actual-function fixture modes (GCC/Clang, plain and ASAN/UBSAN),
57 cases each. The four affected kernel objects compiled as AArch64; the
registry export and atomic caller were checked. The signed text receipt has
SHA2561af91216686e38b3726f2dc0d3288b3c67b75fe1c561fae4e905a90533c3ef59,
with both signatures verified against the pinned COPR key. The native build
took455seconds. It contains no Image and was not installed on the tablet.

The full3 source recipe preserves actual7342 and its complete recipe inverse.
It keeps every earlier hardware/configuration check, reruns the ABM fixture
on the production source and preserves the native13 source proof through an
exact two-string audio-version inverse. The existing RGB client dependency
moves from core to the desktop metapackage so lean rescue can resolve core.
Full compilation, signed delivery and physical level-change/suspend tests
remain required. Full3 is unreserved and published7342 is unchanged.

The separate room-light report uses KDE's default linear0..10000lux curve.
Actual83..119lux readings map near the native visible minimum21/2047. The
existing Control OSS normal-curve import is queued with reversible preferences;
fresh-session application and physical response remain pending.
