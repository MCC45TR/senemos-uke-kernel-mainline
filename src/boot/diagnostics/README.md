# Read-only camera boot graph audit

The two GPL-2.0-only kernel helpers are retained byte-for-byte from the withdrawn
6000 composition and the 7006 source archive (COPR 11253472). The COPR worker
adds return-site instrumentation to temporary header copies. The original
headers remain unchanged. The native application is C++; C preserves the
kernel helper code and libfdt behavior.

The installed tool reads a bounded FDT and executes the camera conversions on
a private RAM copy. It prints only return codes and source line numbers. It
does not write a file, read EEPROM, map physical memory, probe hardware, select
a kernel or reboot. A pass on an already adapted running handoff does not
qualify the original bootloader input or the failed 6000 boot.
