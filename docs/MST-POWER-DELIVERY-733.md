# MST depth and responsive saver delivery

9 November 2026. The next cumulative unstable candidate combines the qualified
source57 MST stream-depth patch and source53 responsive saver patch with the
complete production full10 recipe. Source57 (COPR11292922) qualified both exact
patches, actual callbacks in four compiler/sanitizer modes and ARM64 objects.

The full recipe keeps the production configuration, existing checks, signed
modules, boot container and recovery interfaces. It adds whole-source inverse
checks before compilation and checks the real DP/DPU accessor in `msm.ko` and
the saver provider in `vmlinux`. It does not rerun all callback suites during
the full build. The source receipt and immutable SRPM identify that evidence.

The six existing kernel RPMs remain. No runtime package or daemon is added.
The default MST stream depth remains eight bits; ten-bit requests must satisfy
the sink, port and aggregate bandwidth constraints. SST behavior is unchanged.
MST HDR, DSC, external VRR, multi-sink audio and physical dock/recovery acceptance
remain separate open work. This is not complete DisplayPort feature parity.

Encryption source56 remains available and qualified at the object/configuration
level. This full candidate does not enable that configuration fragment. Its
integration must preserve the independent complete-config comparisons and
existing boot/recovery path before any encrypted volume is considered.

Full build, signed RPM admission, supported DNF transition and tablet tests are
separate acceptance steps. Keep the accepted rollback kernel during delivery.
