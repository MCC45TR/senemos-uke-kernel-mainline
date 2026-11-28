# Linux 7.3.6-31 unstable source candidate

This directory preserves the exact recipe submitted to [COPR build
11403336](https://copr.fedorainfracloud.org/coprs/build/11403336/). Its
Source491 is `uke-dock-journal-followups.tar.xz` in `../../inputs/`.
The other source members are inherited from the signed 7.3.6-30 unstable
source RPM. The expanded Source491 patches and their order are available in
[`kernel/patches/uke-dock-736`](../../../../../kernel/patches/uke-dock-736).

`project-followup-spec.sh` composes the separate reliability layer onto a
later cumulative recipe with a caller-selected unused source number. The
corresponding sample diff shows where it would apply to the preserved
candidate recipe. The layer is `uke-post31-reliability-followups.tar.xz`
in `../../inputs/`. Its Bluetooth, SMMU, GPR, SSC and AudioReach patches
are available in
[`kernel/patches/uke-reliability-736`](../../../../../kernel/patches/uke-reliability-736).
They passed the signed [ARM64 source check
11403377](https://copr.fedorainfracloud.org/coprs/build/11403377/) and await
runtime qualification. These inputs do not change the default build recipe.
