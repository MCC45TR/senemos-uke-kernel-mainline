# Offline charger target handoff

7 November 2026, POCO Pad X1, signed cumulative 7.3.3-3-unstable. The
installed Image contains the AArch64 switch-root helper and its service
drop-in. Its explicit charger branch passes an unsupported --unit option to
systemctl. Original systemd262.2 rejects that argument in option-only help
parsing, without any request to PID1. The existing decision fixtures do not
exercise that command, so they cannot detect the failure.

This establishes a handoff defect. It does not prove whether an actual cold
cable-in boot delivered a charger signal, or explain every earlier KDE boot.
Normal7333 boot and the installed UI report no charger mode. No firmware flag,
electrical setting or bootloader write is used to manufacture that signal.

The candidate keeps normal systemctl --no-block switch-root and systemd's
existing serialization and recursive /run transfer. A matched root generator
selects the existing charger target through the early generated default.target
alias. It requires the exact Uke/SM7675 boot signal, safe native root payload
and a root-owned private version2 handoff marker. Output goes to the standard
second generator argument, the early directory, above ordinary /etc defaults.
Persistent desktop defaults are preserved. Noncharger/conflicting/missing/
unsafe inputs select nothing; an existing different output is not overwritten.

A simple alias under /run/systemd/system loses to /etc. Writing generator.early
before generators run can be discarded. Passing an init command string to
SwitchRoot is also unsupported: the protocol accepts root/init paths, and an
explicit init pointing to systemd is suppressed. The candidate uses the real
generator lifecycle instead of these shortcuts. No second UI or resident
service is added. Root firmware/modules are still required; encrypted-root
key availability and damaged-root charging are independent future work.

The root generator is intended for the existing native integration package.
The following cumulative kernel must require its versioned capability, and
the helper independently checks its safe executable path before creating a
handoff. Neither component is installed by this source draft. Rollout requires
an admitted root RPM, supported DNF upgrade/rollback and cumulative kernel
source, Image and artifact checks. Existing source fixtures retain their
assertions and gain only the new matched-generator prerequisite.

Draft COPR tests cover22 actual filesystem/boot-contract cases with GCC,
Clang, ASan and UBSan. Eight negative mutation controls cover signal, marker,
output-directory trust and collision errors. Original systemctl rejects the
old option; supported syntax is parsed through help without executing any
SwitchRoot request. Real systemd path resolution, exact installed artifacts
and physical charger entry/keys/blank/unplug/current remain separate gates.
No new native test has run yet. No compiler, donor script, generator or boot-changing test runs on the tablet.

## References and attribution

- Existing Uke native offline UI/parser/initramfs implementation, MIT. This
  change reuses its exact board/signal contract and does not add another UI.
- Original systemd262.2,63511d7283d7d0e2a2fc28075481afaf1a7be8f5:
  src/systemctl/systemctl-switch-root.c and src/core/{main,dbus-manager}.c,
  LGPL-2.1-or-later. Review supported argument and handover semantics; no
  systemd implementation is copied or forked.
- ianchb/xiaomi-charger-mode,0c00fcd2cb064f563f44babb345c1dffecf2ada2:
  cmdline service/state comparison only. Python/authentication behavior is not
  adopted; copying licence closure has not been established.
- yzddmr6/xiaomipad-6pro-mainline,01d713340c93adf306f15726bfb6bd3bbf1cc8b2,
  device/charger-mode/liuqin-charger-mode, MIT. Source explicitly describes a
  later stage that its current builder does not include. Board backlight,
  power/CPU settings and electrical authentication are not portable.
- Exact Uke OEM5712080a4b0c0b1a879e6d145c601c649ddaddfd retains product-gated
  charger_partition_poweroffmode handling. That persistent writer is not used.
  Pad8Pro's normal charging policy is not a charger-only boot implementation.

New project code is MIT. Selected references remain unchanged outside the
working source. Source and build success cannot mark OC-01..14 physical
acceptance complete or justify changing charger protection ownership.
