# Preserve the firmware MDP clock during early boot

Lesson ID: UKE-DISPLAY-HANDOFF-20261116.

On POCO Pad X1, a 16 November 2026 boot recording contains about 4.4 seconds
of uniform gray followed by about 1.2 seconds of black between the initial
firmware framebuffer console and native DRM scanout. The complete console
interruption is about 5.7 seconds. The last visible kernel messages are near 1.45 seconds; the
native panel produces its first checked frame near 7.16 seconds. This occurs
before graphical login. Temporal correspondence alone does not establish
which register operation causes the visible failure.

The Uke DISPCC adapter cloned `clk_rcg2_shared_ops` for the MDP source.
Linux 7.3.4's `clk_rcg2_shared_init()` calls the normal disable path, which
records the inherited configuration and immediately parks the live RCG on
the safe source. DISPCC registers around 1.53 seconds, while the firmware
still owns scanout. Skipping PLL reconfiguration alone does not preserve
this MDP configuration.

Use the existing upstream `clk_rcg2_shared_no_init_park_ops` instead. Its init
reads the inherited configuration without switching the clock. Normal
consumer enable, disable, parent changes and rate changes remain upstream
operations. Uke voltage admission, proxy votes, runtime PM, DMA drain and
the checked MDSS reset/SMMU transfer remain in place. No DT resource, voltage,
frequency, firmware ownership gate or permanent clock hold is added.

The exact Linux 7.3.4 source is the primary implementation reference:
`drivers/clk/qcom/clk-rcg2.c` and `clk-rcg.h` (GPL-2.0-only). Uke OEM
`dispcc-pineapple.c` at `5712080a4b0c0b1a879e6d145c601c649ddaddfd`
provides the exact Cliffs MDP tables and regulator contract. The shared-IP
SM8550 reference at `1fb56e66091e71160d7c7f8e13b065d5b6ab8b8c` also contains the upstream no-init-park
operations. OEM display ownership and its Android splash lifecycle differ;
they do not establish native Fedora handoff acceptance.

The COPR fixture runs the actual upstream init/disable/enable functions with
four synthetic inherited configurations, verifies zero registration writes,
checks normal park/restore and rejects both the old parking initializer and
a missing-cache mutant. GCC/Clang with and without sanitizers and a real
AArch64 DISPCC object are required. These checks do not prove an optical
fix: the matched cumulative kernel must subsequently be signed, delivered
through DNF and observed during a fresh boot. A full first-setup reflash and
independent rescue tests are outside this gray-screen experiment.

## Recorded device result, 17 November 2026

The later bounded webcam baseline on kernel7.3.4-4 refines the initial timing:
4.33 seconds of uniform gray and approximately0.90 seconds of dark transition.
The earlier timing above describes a separate initial recording. Use raw
`dmesg` or `_SOURCE_MONOTONIC_TIMESTAMP` for early kernel correlation;
`journalctl -o short-monotonic` can show delayed journal reception instead.
The gray begins within one30fps frame of DISPCC registration and ends near
the checked MDSS handoff.

Source qualification11336575 and cumulative full build11336625 succeeded.
Signed kernel7.3.4-5 RPMs were installed through DNF. Control27 and firmware18
restore the updater's exact admitted factory input sources after the storage
layout stopped exposing Android ODM; the existing identity, private profile,
signature, slot readback and rollback checks remain required. The normal
updater staged slotB while preserving accepted kernel4 in slotA.

Two normal kernel5 boots were recorded for90seconds each, without audio.
All5393 captured frames were analyzed numerically and the transition sheets
were inspected. Neither recording contains the previous sustained gray
interval; the early console remains visible until native MDSS takeover.
The two recordings total about7MB of video. Both boots report complete native
status, no issues, accepted kernel5/slotB and no failed units; persistent
preferences, enforcing SELinux, integrity lockdown and the exact recovery
slotA image remain unchanged.

This fixes the measured early multi-second gray defect in these two normal
boots. Native takeover still clears the console for approximately0.20/0.30
seconds and then goes dark for about0.53 seconds before the native console
returns. A later graphical-session blackout also remains. These recordings
do not qualify cold power-on, suspend/resume, the camera or the other open
hardware requirements. Private videos and unit logs are retained outside
the public source tree.
