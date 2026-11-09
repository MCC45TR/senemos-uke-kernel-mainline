# Staged internal surround profiles

9 November 2026. Unqualified source preparation only. Do not install these
profiles before the six/eight input FE/LPASS implementation and protected graph
are admitted together in a cumulative kernel.

`prepare-surround-profiles733.sh` stages a new topology and UCM tree without
changing installed files. It widens only the dedicated speaker FE maximum from
four to eight, retaining the4/6/8 kernel constraint and every protected backend,
RX/TX/VI, microphone and DP node. A complete text inverse must match the previous
topology. Native qualification recompiles both variants and checks that only
the FE capability bytes differ in the resulting binary.

The old HiFi verb and quad PCM remain unchanged. Two new verbs present5.1/7.1
program inputs through the real hardware PCM at six/eight channels, avoiding a
userspace downmix to four. MFC performs that downmix before the four protected
physical amplifiers. Comments describe four outputs rather than claiming more
physical speakers or a spatial/Dolby algorithm. All existing input sample
formats remain; extra container bits do not establish extra DAC resolution.
Usual PipeWire session mixing/resampling is separate from this DSP operation.

Both new speaker files are derived from the existing HiFi file with only
PlaybackChannels and PlaybackPCM changed. The native original ALSA parser must
verify that inverse, all microphone/DP/control data, and both verb definitions.
Capture rules are staged for the existing kernel-version-scoped integration so
the microphone keeps its physical AUX channel identities under the new verbs.
The global rule and older kernel UCM directories must remain unchanged.

The original Fedora ALSA/PipeWire/WirePlumber/KDE packages remain the consumers.
No new RPM, daemon, CPU sample mixer or desktop fork is introduced. This source
has not been natively tested, installed or physically accepted. Complete the
source/native tests, cumulative linkage/RPM ownership, DNF and A/B checks, then
test each input, center/LFE, all rotations, STOP/reopen, capture/DP coexistence,
suspend and rollback on the tablet. Preserve the accepted quad path throughout.
