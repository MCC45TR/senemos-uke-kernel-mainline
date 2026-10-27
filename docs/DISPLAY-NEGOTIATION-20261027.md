# 27 October 2026: DisplayPort compression and color negotiation

Environment: POCO Pad X1 source profile, signed Linux 7.3.0, host GCC/Clang
production-function fixtures and AArch64 objects. No physical display or panel
trial was performed for this change.

- RGB DSC selects the highest admissible OEM DTO rate: 12 or 8 compressed bpp
  for 8-bpc input; 15, 10 or 8 compressed bpp for 10-bpc input. Link/FEC budget,
  receiver DSC precision, slice geometry and upstream RC tables remain required.
  TU consumes the PPS chunk size, including partial-byte and lane padding.
- Compressed MST keeps DSC in connector atomic state, budgets the 63 payload
  slots across attached streams and enables the standard DRM DSC payload flag.
  PPS, DTO and BE placement use the stream's bank. Shared decompression and
  passthrough AUX flags remain enabled until the last referencing stream stops;
  physical FEC is released only with the physical link. DPU still rejects
  configurations exceeding available mixers, interfaces or DSC blocks.
- Optional native 4:2:0 uses the existing DPU CDM. The exact Cliffs OEM CDM offset
  is relative to the MDP base; the upstream shared CDM implementation is reused.
  HDR BT.2020 conversion is not invented for this native 601-limited matrix.
- A DP-to-HDMI protocol converter can select RGB-to-YCbCr 4:2:2 or 4:2:0 only
  when its detailed DPCD capabilities and the monitor's EDID permit it. TMDS is
  budgeted after conversion, independently of the DP DSC byte stream. Writes
  preserve unrelated converter bits, verify readback and attempt rollback on
  any error. A failed converter transaction refuses stream enable.
- O82 AVR arithmetic uses the actual 32-bit pixel-period limit instead of an
  unrelated 16-bit line limit. One-hertz arithmetic passes host checks, but the
  panel/TDDI path remains guarded below 30 Hz. Existing 30-89 Hz requests keep
  their 90 Hz mitigation. No 1 Hz panel capability is advertised or enabled.

Source comparison: MiCode display `44275c404a677d9d9e5230fedd1af2ef02fc7b9a`,
display DT `4a3e1c391130237c5e8c2b250d1c94f3e25b9b11`, same-SoC Nord4 modules
`1138e00fee63582a0cc6a53af3286621786827b7` and signed upstream Linux 7.3.
Existing GPL attribution remains in the corresponding files and patch.

Physical acceptance remains open for adaptive rates, compressed MST, converted
color output, sustained USB/audio and low-cadence panel/touch behavior. The
current JH925 report has two negotiated HBR2 lanes and no MST capability; source
support cannot change that report. DSC does not increase the downstream HDMI
TMDS limit, and this monitor is not a 4K acceptance fixture. MST HDR and native
YCbCr 4:2:2/4:4:4 source packetization are not included in this candidate.
