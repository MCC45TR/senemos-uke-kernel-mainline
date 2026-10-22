# NT36532 Uke protocol foundation

22 October 2026. Host C fixtures and an AArch64 Linux 7.2.12 translation unit.
The tablet continues to use the packaged userspace touchscreen implementation.

`src/input/nt36532-uke-protocol.c` contains the GPL-2.0-or-later normal RAM
download, raw-frame admission, watchdog and charger-noise protocol. It derives
from the same separately licensed `touch-normal-probe.cpp` and
`touch-thp-packet.hpp` retained in the reviewed `uke-hw` source archive.
It does not include the GPL-3 userspace wrapper or Apache-licensed contact
processing algorithm.

The comparison sources are MiCode touch revision
`15798a6c73e37643c627c00579932fd483a7fcc8`
(`p81/nt36532/nt36xxx.c`, `nt36xxx_fw_update.c`, `nt36xxx_mem_map.h`), Uke OEM
kernel `5712080a4b0c0b1a879e6d145c601c649ddaddfd` and DT
`94c84aeb9e517dbde546fc732033c184094c8e57`. The existing Uke protocol and
protected firmware identity select the exact bank layout; adjacent tablets'
coordinate parsers and board settings are not substituted.

The consumer supplies bounded SPI callbacks, SHA-256 and a panel-readiness
check. Every transfer and final successful operation checks readiness; the
future transport must serialize panel generation changes with transfers.
Callbacks return zero on complete success or a negative errno. Positive
results are rejected. Image size, header and full SHA-256 must match before
device I/O. All four banks are read back before boot-ready is written.

A validated 5,432-byte frame retains its counter, scan type and 2,400 signed
little-endian raw nodes. The returned matrix pointer borrows the caller's
frame buffer. The values are not labelled as signed deltas: reference
subtraction still belongs to the existing contact processor.

## Host checks

`make test-touch-protocol` compiles the actual C file and injects failures at
380 individual transfers and 382 readiness checks. It also checks corrupt
packets, image refusal, foreign chip/topology, bank mismatch, timeouts,
operation-mode responses and charger-command readback. The default fixture's
synthetic SHA callback tests control flow, not cryptographic admission.

Optional private inputs extend the same test runner:

```sh
UKE_TOUCH_REFERENCE_DECODER=/private/source/touch-thp-packet.hpp \
UKE_TOUCH_NORMAL_IMAGE=/private/normal.bin \
UKE_TOUCH_SANITIZE=1 bash tests/touch-protocol-contract.sh /private/frame.bin
```

The original C++ decoder and this C implementation agreed on 10,000 generated
frames, 80,000 mutations, 10,000 watchdog packets and one retained private
frame. An independent OpenSSL SHA-256 check admitted the retained normal
image and rejected one changed byte per 1 KiB. GCC ASan/UBSan checks passed.
The AArch64 object compiled against the prepared project Linux 7.2.12 source
with Clang 23.1.3 and `KCFLAGS=-Werror`; this is not a linked driver build.

## Remaining integration

No Kconfig, transport probe, DT binding or packaged tablet payload selects
this foundation yet. Kernel SPI/IRQ ownership, panel lifecycle, a lossless
standard capture interface and the existing userspace contact consumer must
be integrated together before replacing the current transport. Suspend,
resume, generation changes, watchdog recovery and physical touch/VRR
continuity then require separate tablet tests. The standalone touchscreen
package remains necessary until that replacement is qualified.

Private firmware and reference data are not distributed with this source.
