# Source layout

`kernel/overlay/` mirrors Linux paths for the Uke ARM64 entry code, Qualcomm
device-tree inputs, CAMCC and CAMSS, DRM, SSC IIO, the NT36532 touchscreen,
USB Type-C, UFS and ASoC. Devicetree schemas and sysfs interface
specifications live beside the kernel inputs under `Documentation/`.

`kernel/configs/base/` contains shared ARM64 and Fedora fragments. The Uke
board fragment lives in `boards/`, optional fragments in `features/` and
the native configuration in `profiles/`. The active configuration is
computed by the RPM spec.

`kernel/patches/series` records the initial adaptation order.
`release-delta.series` records the last three patches appended to the signed
7.3.5-45 parent. The RPM spec retains the order and checks for the intervening
cumulative layers.

`kernel/source-layout.tsv` maps each browsable release input to its digest and
exact source archive member. These files show the published inputs at their
source preparation stages. Later patches in the spec can modify those
inputs. The published SRPM preserves the complete build graph and archive
identities. The worker rejects a browsable file that diverges from its
corresponding input.

`boot/` exposes files from the signed boot recipe. Build these through the
RPM worker, which supplies the other boot assets and the prepared kernel.
`tests/fixtures/` contains archived fixture sources. The RPM spec runs their
corresponding checks with the matched driver source and toolchain.
