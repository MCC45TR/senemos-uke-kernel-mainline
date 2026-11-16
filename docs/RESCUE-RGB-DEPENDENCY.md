# Keep the optional RGB status client outside the rescue kernel core

16 November 2026. The accepted 7.3.4-2 core RPM requires
`uke-control(rgb-charge-status-v1) >= 1`. Native rescue assembly with that
exact signed cohort failed during DNF resolution because the rescue repository
admits firmware and kernel inputs, while the full desktop Control package is
excluded. No rescue filesystem or super seed was produced by this attempt.

The kernel implements battery LED events independently. Its desktop status
reader remains required for the normal installation through the main kernel
metapackage. Moving that single requirement out of core preserves the desktop
dependency while permitting an independent rescue kernel/module installation.
This does not remove any kernel feature, module, signature or hardware guard.

`move-rgb-client-dependency.sh` accepts only the exact published7342 recipe,
moves that requirement to the main package header, proves the whole reverse
transformation and queries the actual RPM dependency headers for both packages.
It is a source-only preparation for the next cumulative release. The published
7342 RPMs are unchanged. Full3 remains unreserved, and must retain all7342 code,
config, DT, firmware and signatures along with qualified early rescue handling.
An image using this dependency correction still needs normal signed DNF
resolution, bounded filesystem composition and actual independent rescue boot.
