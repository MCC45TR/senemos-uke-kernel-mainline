# Preserve the firmware MDP clock during early boot

Lesson ID: UKE-DISPLAY-HANDOFF-20261116.

On POCO Pad X1, a 16 November 2026 boot recording contains about 5.7 seconds
of uniform gray between the initial firmware framebuffer console and native
DRM scanout. The last visible kernel messages are near 1.45 seconds; the
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
