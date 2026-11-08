# Native dual-light kernel delivery

The cumulative unstable recipe adds the qualified shared SSC stream ownership,
combined standard IIO light endpoint and passive Hall subscription before the
real Image and module build. The existing protected audio gain223, Hall initial
GPIO observation, camera/display admission, memory configuration, firmware paths,
automatic A/B staging and persistent rollback preference remain in the parent.

`copr-dual-light-delivery733.sh` supports a source/object check and a full build.
A full build requires the same current source commit and versioned successful
check receipt, pinned by its independently verified RPM digest. Older source-only
entries still refuse full builds. A signed source-check receipt is never installed.

The source check executes the actual production preparation helper on isolated
copies of four prepared source files, compares every inverse byte with the parent
and refuses re-entry or unrelated driver/header/binding/Kconfig/history changes.
Its postimages must equal the actual ARM64 driver and early-DT compilation inputs.
Both native and boot recipe archives carry the same new assets and manifests.

Full builds retain both historical build-phase SSC comparisons. The production
helper applies all six reviewed patches before `build-payload.sh` compiles Image
and modules. Linked checks first authenticate the real postimage and inspect its
input/IIO imports, registered callback symbols, early-DT link, module ABI and signed
compressed module. Older source comparisons use a whole-patch inverse view. They
continue inspecting the actual new objects, never substituted historical objects.

The spec rewriter is tested against the exact previously delivered full5 spec,
including a whole-text inverse and eight order/identity/re-entry refusals. That
fixture tests the transformation; the new actual full build remains a separate gate.

This does not establish runtime-board DT validation, physical cover/light/power
acceptance, original SensorProxy parity or permission to retire a provider. The
closed-cover GPIO path and normal IRQ/resume must be measured separately on Uke.
Brightness units, acquisition, desktop curve and observed comfort are separate
requirements. There is no new polling timer, daemon, forged sensor capability or
desktop-package fork. Gain243 remains conditional on qualified physical protection.
