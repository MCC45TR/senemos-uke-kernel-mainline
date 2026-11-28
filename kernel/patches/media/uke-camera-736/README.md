# Native Uke camera discovery for Linux 7.3.6

The discovery layer uses the fitted Xiaomi Pad 7 / POCO Pad X1 camera
resources on SM7675. It adds the guarded front and rear identity reads,
CCI0 master 1, and the native CAMSS receiver with the `qcom-camss` Media
Controller ABI used by Fedora libcamera.

The six groups have source checks for the cumulative Linux 7.3.6-unstable
recipe. `camera-discovery.sh` applies them in dependency order, verifies
linked objects, and restores the source after the build. The numbered RPM
patch shows how to invoke it in the matching 7.3.6-unstable recipe. The
current 7.3.5 release series uses its existing build inputs.

The packaged source is `uke-camera-discovery-736.tar.xz` under
`packaging/rpm/kernel/inputs/`. `SHA256SUMS` and `kernel/source-layout.tsv`
bind the archived inputs to their readable copies. The two `.dtso` files
are reference projections for the resources and bus, while the production
boot graph comes from the numbered patches.

The first device check requires the expected signed kernel and checks the
receiver, its media ABI and, in explicit identity mode, the fitted sensor
IDs. Stream links, image capture, calibration and rear focus still require
separate qualification.
