# Uke KVM package candidate

20 October 2026. Fedora Rawhide AArch64 source/package profile; no device boot.

`senemos-uke-linux-kernel-mainline-kvm` uses the current 97-patch native hardware
profile, including its upstream CONFIG_KVM selection. The separate `-kvm`
module ABI prevents mixing its Image and modules with the ordinary kernel.
Both the EXT4 Linux and F2FS userdata containers contain its same Image.
The corresponding singleboot package selects that exact userdata tuple.

No package script activates a kernel or changes a slot. Upstream KVM still
requires actual EL2 ownership, working secondary CPU entry, interrupts, timers
and firmware services. CONFIG_KVM or a completed build does not establish
those conditions. The optional native `uke-kvm-probe` runs only on an explicit
request; its unavailable/error results must not be reported as a running guest.

The older 77-patch EL2 research branch and its unqualified optional early-exit
experiment remain separate retained evidence. This current package does not
invoke an early firmware-exit SMC, copy security firmware or reclaim reserved
memory. Preserve the accepted normal kernel, matched modules and recovery.
