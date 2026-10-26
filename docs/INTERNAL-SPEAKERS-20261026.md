# Internal speaker path, 26 October 2026

Environment: POCO Pad X1 (Xiaomi Pad 7, SM7675), Fedora Rawhide AArch64.
Tablet probes ran on the installed Linux 7.3.0-16 kernel; source checks ran on a
prepared Linux 7.3 tree (116 patches, `audio-profile` = `speakers`).

**Status: source and host results only, plus amplifier-driver results on the
tablet without any audio output. No sound has been produced.** The TDM bit
clock, DSP graph, LPASS pin control and card have not run on hardware. Do not
mark internal speakers working before the tests in the last section pass.

## Evidence

- OEM device tree: four `fs19xx_smartpa` nodes at 0x34-0x37 on QUP1 SE3
  (`i2c@88c000`, SDA gpio44, SCL gpio45), reset gpios 30/149/124/123.
- OEM preset `fs19xx.fsm` (stock odm image): valid CRC, four devices, positions
  top-left 0x34, top-right 0x35, bottom-left 0x36, bottom-right 0x37.
- Stock backend configuration: `TDM-LPAIF_VA-RX-PRIMARY`, 4 channels, 32 bit,
  48 kHz, slot mask 15.
- Stock ACDB graph `a2000001` (metadata only): TDM sink module `0x0700100E`,
  LPAIF type 3, index 0, four 32-bit slots, lane mask 2, sync source 1, data
  delay 1, data out enabled. The DSP algorithm module in that graph is not used:
  the OEM FS19xx driver sets `nondsp_mode`, i.e. the amplifier protects itself.
- OEM LPASS pins: `lpi_tdm1_*` = gpio6 SCK, gpio7 WS, gpio8 SD0, gpio9 SD1,
  function 2, which is `i2s1_clk/ws/data/data` in the SM8650 LPI table.

Donors: MiCode `vendor_qcom_opensource_audio-kernel` `uke-v-oss`
(`8eb0eccb`, FourSemi GPL driver) for register sequences and preset layout;
AudioReach graphservices `76d04ffb` (BSD-3-Clause) for graph metadata formats.
No preset, tuning or calibration data is stored in this repository.

## Changes

| Area | Change |
|---|---|
| `patches/7.3.0/0115` | `fs19xx` ASoC/I2C driver. Active-low reset held while idle, OEM start sequence, DAC muted until the amplifier reports PLL lock, output switch default off, digital volume capped at the OEM uncalibrated limit (0xDF, -12 dB). Preset parsed with size, CRC and bounds checks. A missing preset leaves the card usable and the speaker disabled. |
| `patches/7.3.0/0116` | AudioReach legacy TDM sink/source (`0x0700100E/F`): interface config `0x0800101B`, lane mask `0x0800106A`, endpoint format `0x08001017`, clock attributes `0x0800113C`, plus the topology token loader. |
| `src/audio/uke-audio-card.c` | `xiaomi,uke-speaker-audio-card`: HDMI and four-amplifier TDM backends in one card, fixed 48 kHz / 4 ch / S32, CPU slots 4 x 32. |
| `src/audio/POCO-Pad-X1.conf` | HDMI graph unchanged plus `MultiMedia2` (4 ch) to the TDM sink behind `SECONDARY_TDM_RX_0 Audio Mixer`. |
| `src/audio/sm7675-uke-speaker-audio.dtsi` | Amplifier bus and nodes, LPASS LPI pinctrl for gpio6-9, two-link card. |
| `src/display/uke-abl-native.h` | Publishes symbols and phandles for the four unlabeled OEM amplifiers before the overlay applies. |
| `configs/uke.config` | `SND_SOC_FS19XX=m`, `PINCTRL_SM8650_LPASS_LPI=m`. |
| `packaging/native` | New `speakers` profile (now selected); `hdmi-only` remains selectable. |

## Results

Host (no device):

- The 114 existing patches plus the two new ones (116) apply to pristine Linux 7.3.
- `prepare.sh` completes for the `speakers` profile, including the new
  `speaker-audio-fdt-contract.sh` and `speaker-audio-topology-contract.sh`.
- `audio-fs19xx-contract.sh` (actual parser and register-table functions, ASan and
  UBSan): valid presets, every rejection path, field read-modify-write, delay and
  wait pseudo-ops, scene filtering, no leak on rejection. With a private OEM
  preset supplied through `FS19XX_PRESET` it parses for all four addresses.
- `audio-tdm-sink-contract.sh`: the actual encoder produces the four parameter
  blocks with the stock values; slot overrides and allocation failure covered.
- The generated overlay applies to a copy of the running device tree, and the
  project's native ABL fixture passes with the new symbol assertions.
- Existing audio contracts (GPR, PRM, graph, card, preset, ACDB) still pass.
- `mainline-package-contract.sh` and `unstable-package-contract.sh` need
  `rpmspec`, which was not available; they were not run.

Tablet, Linux 7.3.0-16, no reboot, a throwaway dev-only module (not part of
these patches) supplied a GPIO I2C bus and a fake-clock card:

- All four amplifiers answer: id 0x2900, revision 0x00A2. Preset positions
  0x8/0x2/0x4/0x1 match the device-tree prefixes.
- With the speaker switch off, an open stream leaves the amplifiers in reset.
- With it on and no bit clock, register readback shows chip-init done, run mode,
  all blocks enabled, 48 kHz and data-out set, PLL registers programmed for
  6.144 MHz, volume `0xDF`, `DACCTRL = 0x0310` (muted). The PLL flag never set
  (`STATUS = 0x0200`), the driver stayed muted, and every amplifier returned to
  reset when the stream closed.

## First boot, release 17 (26 October 2026)

The new kernel booted. The overlay applied: the amplifier I2C bus came up, the
LPASS LPI pin controller probed, and three amplifiers probed with the expected
positions (0x34 top-left, 0x36 bottom-left, 0x37 bottom-right). Amplifier 0x35
reported `amplifier not detected`, and because the card waits for all four
codecs, **no sound card registered, HDMI audio included**.

Cause: the reset line was held asserted. The OEM node's active-high `reset-gpio`
and the overlay's active-low `reset-gpios` name the same GPIO, so gpiolib's
shared-GPIO scan put the line behind a voting proxy. For 0x35 the proxy never
released the amplifier (level read back asserted after deassert; a debug build
showed this on eight retries). Release 18 removes the OEM `reset-gpio` in the
native entry, and the driver now registers its component even when the chip is
not detected, so one bad amplifier can no longer remove the card. That speaker
refuses to open a stream.

## Second boot, release 18

All four amplifiers probed and the `POCO-Pad-X1` card registered, so HDMI audio's
card is back. Playing silence on `MultiMedia2` with the route and the four
speaker switches on: the DSP accepted every command, the TDM bit clock reached
the amplifiers and their PLLs locked (`status 0x0242`, so the lock bit is bit 1
as assumed). The DSP never consumed the submitted buffers: four buffer-done
events arrived together only at stream stop, and ALSA reported
`playback write timeout`. The stock graph also programs the hardware-endpoint
frame size factor (`0x08001018` = 1) on the TDM sink, which release 18 omitted.
Release 19 sends it.

## Third boot, release 19: first sound

Release 19 sent the frame size factor but still stalled. A runtime experiment
(extra frontends with different module chains, back-end width as a module
parameter, hardware 26 October 2026) isolated the cause. The DSP returns
buffers while the stream runs only when it does not have to change sample width:

| Chain | 32-bit back end | 24-bit | 16-bit |
|---|---|---|---|
| decoder, converter | stalls | stalls | works |
| decoder, converter, MFC | stalls | works | works |

With a 16-bit back end inside the 4 x 32-bit TDM frame, a quiet 440 Hz tone on
all four channels was audible from the internal speakers. Release 20 therefore
uses an S16_LE back end and an S16_LE-only speaker frontend; wider sources need
the MFC chain, to be added later. The amplifier driver now takes any sample
width because the TDM frame fixes the bit clock.

## Not established

Audible output; TDM bit clock and frame sync; DSP acceptance of the graph;
LPASS LPI pinctrl probing and its clock votes; the combined card at boot; the
`STATUS` bit pattern of a locked PLL (the gate assumes `PLLS` = bit 1); channel
order across slots; speaker calibration (no Re25 data, unqualified);
microphones; suspend; thermal behavior at volume; UCM/PipeWire integration.

## First test after flashing

Install the preset locally (stock odm image, never published):
`/lib/firmware/qcom/uke/audio/fs19xx.fsm`. Packaging this file in the firmware
component is open work.

1. Expect `fs19xx` lines for four addresses (id 0x2900, positions 8/2/4/1), the
   `POCO-Pad-X1` card, and no errors from `uke-audioreach-card`, the LPI
   pinctrl or `q6apm`.
2. Keep volume low (default is already capped). Route and enable:
   `amixer -c 0 cset name='SECONDARY_TDM_RX_0 Audio Mixer MultiMedia2' on`, then
   `Speaker Switch` on for `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`.
3. Play four-channel S16 at 48 kHz with `aplay -D hw:0,1 -c 4 -f S16_LE -r 48000`.
4. Watch `dmesg` for `status 0x.... after N polls`. If the PLL never reports
   lock, the output stays muted by design: record the value, then retry with
   `snd_soc_fs19xx force_unmute=1` only for a short, low-level test.
5. Any distortion, buzz or heat: switch the four `Speaker Switch` controls off
   and stop the stream; amplifiers return to reset.
