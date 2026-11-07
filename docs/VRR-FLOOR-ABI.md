# O82 saved-floor API metadata

7 November 2026. On kernel12217 the original KDE compositor reports DSI VRR
incapable. The runtime request floor is0 and the existing per-device userdata
update preference is0; fixed internal modes remain120/144/90/60/50/48/30Hz.
The stock compositor's missing setting follows the kernel capability state.
This is not evidence that the fixed modes vanished or a reason to fork KDE.

A separate interface omission prevents the packaged saved-floor loader from
recognizing the kernel: it requires both uint parameter type fields and the
ABI1 marker. A custom module_param_cb does not generate parmtype metadata.
The installed module lacks the existing floor's type and the marker itself.
Add the two explicit type fields and a getter-only0444 API1 marker, with no
setter. Keep the floor's transactional30–143 parser, zero default, exact board,
bonded receiver/mode and atomic admission unchanged. No display timing, panel
command, register value or generic capability advertisement is modified.

An explicit user request to restore VRR uses the existing per-device updater
preference and its qualified boot-header derivation at delivery. Shared package
preferences and kernel defaults stay unchanged; other saved choices persist.
The installed updater's declared root-selector ABI admits only0/30 and verifies
that derived boot wrappers preserve the signed kernel Image. A saved requested
floor alone does not prove physical cadence or transducer/display stability.
Current source does not establish adaptive sync on an external monitor.

Linux7.3.1 include/linux/moduleparam.h at
79a907609d53d5cd645b42c11550d295d43abf99 defines module_param_cb without type
metadata and module_param_named with __MODULE_PARM_TYPE. This primary kernel
interface, GPL-2.0, is used directly; no alternate implementation is copied.
The pinned Uke OEM/same-SoC inventories and existing O82 donor research remain
unchanged because no board value, receiver check or display algorithm changes.
See O82-VRR-EXPERIMENT.md and the cumulative display manifests for exact OEM
profiles and physical qualification limits. New project code isGPL-2.0-only.

COPR executes the actual parameter block with independent parser/provider
stubs,207 cases in four compiler/sanitizer modes. Writable API and wrong-version
mutants must fail both compilers. Whole-file reverse comparison proves only the
API/type block changes; exact block hashes and actual AArch64 dpu_encoder.o
metadata/symbol checks are mandatory. Combined source admission must retain the
atomic idle speaker correction, all463 complete17 nonidentity fields and every
historical native control. Physical KDE visibility and cadence remain separate.

Source check39 passed all four74-case idle modes, original17 controls and
four assertion mutants, then failed a missing output-fault provider in a retained
unprotected codec fixture. Release40 combined VRR before this failure was
observed. Release41 adds the callback to two historical synthetic peers, with
exact pre/post hashes and unchanged assertions. Protected idle testing still
executes the actual atomic runtime function. No production audio change follows
from this fixture correction. Native and physical qualification remain required.
