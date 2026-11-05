# Uke pogo keyboard backlight

5 November2026. The standard uke-pogo::kbd_backlight LED is now registered
after an actual attachment report and removed on detach. Its range remains
0-100, with the exact Uke0x23 command. Reconnect keeps the selected brightness;
suspend and lid/fold inhibition retain the request for restoration. Detached
nonzero writes fail and failed transport writes do not replace the accepted
request. Registration, removal and their callbacks run outside the I/O mutex;
a detach racing registration removes the stale endpoint. Probe/removal cancels
the worker before freeing driver state.

Input and backlight commands remain inhibited until the current host token is
successfully delivered. Delivery is not renamed as MCU authentication acceptance.
A new attachment/authentication resets that gate and releases held inputs;
ordinary suspend retains the powered MCU session while invalidating pending
challenge epochs. The standard bridge_health reports delivery as a boolean.

The original Fedora PowerDevil6.8.2 caches keyboard support at construction.
UPower1.91.5 tracks standard LED add/remove, while the original Plasma applet
tracks PowerDevil registration and supported actions. The separate original
C++ uke-pogo-desktop helper therefore waits for UPower and requests a restart
of the existing user PowerDevil service once per real attachment change when
its cached capability is stale. No KDE/GNOME source or package is forked.

Power enable is explicitly Uke's order: L22B/vdd3.3V then L23B/dvdd1.8V;
stop reverses it. Partial enable cleanup only removes acquired votes. This
comes from Nanosic_switch_regulator and Nanosic_regulator_init in the Uke
archive9bb7c4331be7205fabf5427b5654555763304d20, module SHA
0f24da97082902f801b5577565753628b34324aeae0ec8ecd2c51520d9718498.
The archive differs from the older measured Global304 module41c42124 and is
not relabelled as that release. Voltage fields264/272 are3.3V/1.8V and the
enable calls at108c8/109e4 establish order; the shared WN8030 donor's I/O-first
sequence is not transplanted. GPIO timing and admitted MCU image remain exact.
Neither module is executed or included in source/build artifacts.

The real device currently fails its first MCU I2C write. The physical keyboard
is unavailable, as confirmed on5 November; this does not establish the cause
of the transfer failure. The change removes the unordered power assumption,
but a physical retry on a coordinator-delivered cumulative kernel is required.
The same archive's gTouchDevice points to its277-byte HID_TouchReportDescriptor
at.data+0xa45. It confirms21-byte input, three repeated contacts per packet,
X3199/Y2135, advertised94x42mm and a maximum of eight contacts per hybrid frame.
The production descriptor's factual fields match that symbol. Protocol checks
now admit Y2135 and contact counts0-8, including zero-count continuation packets;
the feature callback reports the same bounded capacity. Upstream HID multitouch
owns frame assembly and standard libinput gestures. This is source capability,
not eight-contact or physical-size acceptance. Exact accessory input/auth,
effective brightness and complete suspend/wake remain physical gates.
The isolated source/object fixture does not claim a full cumulative kernel.
Only the shared coordinator integrates/delivers the delta with every retained
camera, display, SSC, CDSP, audio, memory and boot contribution.
Use src/pogo/apply-backlight.sh on the extracted profile before its normal
preparation. It admits only the known old/current driver and leaves Kconfig,
Makefile, unrelated sources and feature gates intact. Refresh its profile lock
and require the new lifecycle/backlight/power checks in the final producer.

Isolated COPR11262339 succeeds at source4e478f2076ef653ccf29d9524d3e043ab74666df:
all four actual-callback fixtures pass with GCC and Clang, each ordinary and
ASan/UBSan; the real Linux7.3.1 AArch64 driver object builds with-Werror.
The signed text-only receipt passes both fingerprint signatures and both
digests. Its precise identities and remaining gates are recorded in
manifests/pogo-backlight-check-20261105.json. The receipt is not installed;
this check produces neither a full kernel nor physical acceptance.

The later OEM HID correction needs fresh fixture0.1-2, including a fifth
actual-descriptor/feature check and the expanded protocol boundary checks.
Earlier check11262339 qualifies only its exact4e478f2 inputs.
