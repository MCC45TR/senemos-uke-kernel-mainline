# Protected speaker frontend connection

6 November2026. Full12209/source514536ca boots, but graph40 OPEN returns
DSP24/duplicate and remains quarantined. Calibration staging succeeds; sound
and physical protection remain unaccepted. All four amplifier outputs stay off.

The installed topology has unique module IDs. Its DAPM mixer still connects
to spk.sink, while the protected graph also connects the RX module to that
sink's input2. Linux audioreach_route_load selects the module downstream of
the mixer, and audioreach_connect_sub_graphs places the FE edge at that module.
The resulting OPEN therefore contains two connections to the TDM sink input.
AudioReach's graph utilities reject duplicate input ports. This is a concrete
source/composition defect compatible with the fitted DSP result, without
claiming that it is the only hardware fault.

The protected builder copied from sourcec2932add only rewrites a newer
mixer-to-MFC base route. The cumulative parent deliberately preserves its
older configuration; the rewrite silently misses that form. Accept both
baseline forms and require exactly one entry and one protected chain. Connect
the mixer to MFC, then RX, then the TDM sink; retain VI source to TX and IMCL.
Module IDs, parameters, gain223, private calibration, raw microphones, HDMI,
clock/config/DT gates and boot compatibility remain unchanged.

The native contract compiles and decodes the actual generated topology, then
executes the prepared Linux route callbacks with those module/route records.
It verifies unique source/destination ports, the MFC entry and both protected
chains. The original builder must reproduce duplicate TDM input4433/2. Both
baseline forms must generate identical protected data; missing or ambiguous
routes must refuse. GCC/Clang and sanitizer qualification belongs in COPR.
A following signed RPM/DNF install and matching physical playback tests remain
required. No local firmware replacement, DSP reset or protection bypass is used.

References: Linux7.3.1 sound/soc/qcom/qdsp6/topology.c, Git blob
faafbc5c0ad004b1a1aed1a3a1ad6a73762ebec1, GPL-2.0, Linaro copyright;
AudioReach engine5773bf8e627c9857481dd338a9ec4aea4a49afd3,
fwk/spf/containers/cmn/graph_utils/src/graph_utils.c,
blobeeafe06f8bb0276ab5947ff404b0588ee81d393d, BSD-3-Clause, Qualcomm notices;
qualified Uke protected sourcec2932addf1f9b885a9a559b40d1ce5b7d43fe98b,
retained OEM FourSemi RX/VI/IMCL evidence and exact cumulative12209 capsule.
Reference sources are unchanged. The donor survey and compatibility limits in
the existing speaker research record remain applicable.
