# Optional gaming and Windows runtime interfaces

30 October 2026. This candidate retains the exact Linux 7.3.0-54 hardware
source from COPR 11228863 and changes two kernel options to modules:
`CONFIG_NTSYNC=m` and `CONFIG_BINFMT_MISC=m`. It does not install or recommend
Wine, Proton, FEX, Gamescope, MangoHud or an upscaling SDK. It adds no module
autoload policy, executable registration or global graphics override.

NTSYNC supplies NT semaphore, mutex and event interfaces for a compatible
Wine/Proton runtime. `binfmt_misc` allows an optionally installed userspace
interpreter to register foreign executable formats. Neither replaces an
x86/x86-64 translator on this ARM64 device. The existing 4 KiB pages, futex,
namespaces, seccomp, shared memory and input interfaces are retained.

On the installed release-54 baseline, Mesa 26.2.6 reports fragment shading
rate and graphics pipeline library support, and both Freedreno and Zink are
present. SGSR 1/2 are application shaders; SGSR 2 also needs engine-provided
depth, motion and history. VRS needs renderer integration. MangoHud uses
existing graphics and telemetry interfaces. No additional kernel graphics
driver is needed solely for these features.

Install applications separately when wanted. After booting a matching kernel,
`modprobe ntsync` makes the optional NT device available; a compatible runtime
must actually use it. Interpreter registrations belong to the chosen emulator,
not this kernel package. No default `.exe` handler is registered here.

Remote config, native module architecture, vermagic and signatures are package
checks. A successful build does not establish Wine application compatibility,
SGSR pixel quality, VRS rendering correctness, HUD metrics or an FPS gain.
The current device kernel, matching rollback and explicit boot approval remain
separate from the staged candidate.
