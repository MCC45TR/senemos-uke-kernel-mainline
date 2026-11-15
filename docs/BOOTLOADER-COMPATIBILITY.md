# Explicit compatibility metadata for alternating slots

6 November2026. The12207 trial returns to12206. Protected inspection confirms
that the failed B image is intact and A, preferences and automatic staging are
preserved. A/B original vendor DTBs and DTBO are identical. Both primary AVB
headers have verification disabled; A supplies boot version properties while
B does not. No persistent crash record identifies an instruction failure.

Qualcomm ABL `aef4e86045bd151a54d33bab8ae5e8e62462a8f4`,
`QcomModulePkg/Library/avb/VerifiedBoot.c`, falls back from absent boot properties
to a nonzero boot-header version. Its bundled libavb skips chained descriptors
when primary verification is disabled, so adding a boot footer alone cannot
supply this path. These are generic loader sources, not identification of the
fitted OEM binary. No firmware or primary VBMeta modification is proposed.

The canonical `create` and `pack` modes retain zero version metadata. The new
explicit `create-bootloader-compat` mode uses570425768, the opaque version input
already booted in the existing Uke kernel family. This is bootloader protocol
compatibility data, without an Android or Linux security qualification claim.
It changes only four header bytes relative to canonical creation; Image,
root selector, sizes, padding and refusal behavior remain identical.

Both shipped root profiles select this explicit compatibility mode. Native
GCC/Clang and sanitizer checks compare all three selectors, payload readback,
exact byte deltas and malformed/output/device refusals. Full production image
checks require the selected metadata. Every12207 driver/config/DT/firmware
and speaker protection gate is retained; no stable-family promotion occurs.
All compilation stays in COPR, delivery stays in normal DNF, and matching B
boot plus audio/suspend/USB/Hall tests remain separate hardware requirements.
