# Android network configuration

4 November 2026, POCO Pad X1, kernel7.3.1-7200-unstable and original
Waydroid1.6.3/Android13. The container reaches boot completion and its bridge,
but netd cannot add IPv4 policy rules; the kernel returns an unsupported
operation. The effective configuration disables advanced/multiple-table
routing. Legacy IPv4/IPv6 filter tables are also unavailable inside Android.

Candidate7800 retains the7300 unstable producer, camera stage0 and the
existing recovery/pstore policy. It enables Android policy routing and the
standard legacy filters/matches as built-ins, including owner/mark/BPF rules.
The Android13 [base configuration](https://android.googlesource.com/kernel/configs/+/refs/heads/android13-release/t/android-5.15/android-base.config)
is the reference for Android's requirements. No firewall service is disabled
and no direct route is injected on the tablet.

COPR checks effective settings and compiled objects, preserving unrelated
input settings. Signed DNF delivery, reboot, netd rules, external network
access and repeated application launches need separate device qualification.
The normal/stable kernel family is outside this change.
