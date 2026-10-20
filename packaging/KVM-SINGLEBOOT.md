# Uke KVM userdata package selection

20 October 2026. Fedora Rawhide AArch64 source metadata; no tablet activation.

This package requires the exact matching KVM package, core, modules, DTBs and
boot bundle. Its descriptor selects the F2FS userdata container from that same
Image/module ABI. It publishes a separate `kvm-default-boot.img` link and
performs no partition writes, slot changes or changes to the ordinary default
boot image. Firmware ownership and physical KVM/userdata boot remain unqualified.
