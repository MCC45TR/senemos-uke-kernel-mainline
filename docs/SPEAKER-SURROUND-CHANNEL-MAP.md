# Speaker channel identities and multichannel input

9 November 2026. The requested internal 5.1/7.1 capability needs six/eight
program channels rendered to four physical speakers in ADSP. It must preserve
the protected output graph, calibration/VI identities and display rotation.
Stock Fedora PipeWire/WirePlumber and existing Control remain the userspace
interfaces. Four outputs do not constitute six/eight physical speakers.

Source review finds two concrete prerequisites:

- The current quad coefficient packet names channels1,2,5,6. The actual upstream
  q6apm header and Qualcomm AudioReach media API define FL=1, FR=2, LS=4, RS=5,
  LFE=6. The default four-channel media callback emits1,2,4,5. A table with the
  wrong identity set may fall back to firmware defaults instead of applying the
  requested permutation. This is a source-level explanation candidate for
  incorrect rotation; physical causality is not yet proved.
- The generic AudioReach PCM frontend permits eight channels, while its default
  mapping helper fills only one, two and four. New six/eight-channel cases use
  ALSA's standard interleaved order and real AudioReach identities. Existing
  layouts and unknown-count behavior remain unchanged.

The quad encoder now uses actual q6apm constants. Fixtures obtain those constants
from the prepared kernel rather than repeating the same wrong values. Native
qualification must exercise real extracted callbacks, historical-error refusal,
the whole-source inverse and the real ARM64 AudioReach composite. Existing
speaker route, protection, STOP, rotation and all cumulative checks remain.

This first layer does not expand the current four-channel topology or advertise
5.1/7.1 desktop profiles. Those require an admitted six/eight-channel FE route,
explicit channel-position controls, DSP MFC downmix/render configuration, bounded
gain/headroom, default-preserving prepare/STOP/reopen and real firmware tests.
Coefficient mixing is not proof of spatial virtualization or Dolby processing.
KDE profiles will follow actual ALSA/UCM capability, not an unsupported label.

Primary references, inspected unchanged:

- Linux7.3.3 `d50d994bffa3c7c6db2d8bc4c5f0c55e3f46b0cd`, GPL-2.0:
  `sound/soc/qcom/qdsp6/q6apm.h`, `audioreach.c`, `q6apm-dai.c`,
  `q6dsp-common.c`, and `sound/core/pcm_lib.c` (`snd_pcm_std_chmaps`). The older
  q6dsp helper's LFE-before-FC ordering is not used as ALSA standard ordering.
- AudioReach engine `5773bf8e627c9857481dd338a9ec4aea4a49afd3`, BSD-3-Clause:
  `fwk/api/modules/media_fmt_api_basic.h` and
  `modules/processing/channel_mixer/api/chmixer_common_api.h` specify identities,
  Q14 coefficient tables and fallback to built-in coefficients for no match.
- Uke OEM audio `8eb0eccbc4027ae4a4987e4bced03a4381039714`, GPL-2.0-only:
  `asoc/codecs/fs19xx/fsm_core.c` has the previously reviewed stereo CHS selector,
  not a portable four-output 5.1/7.1 renderer. No other-board calibration or
  proprietary DSP algorithm is copied. A same-SoC native surround renderer is
  not established by the pinned donor inventory.

Native build evidence and physical audio acceptance are separate. Gain remains
223 until the independent243 protection evidence is ready. No new RPM, daemon,
CPU audio mixer or poll loop is introduced by these source changes.
