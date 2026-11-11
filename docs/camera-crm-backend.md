# Cliffs camera CRM transport and LUT work

The AP vote core passed COPR11264022 with the independent OEM contracts,
427488 checks in each GCC/Clang ordinary/sanitizer run, and signed text-only
receipt admission. Its first attempt11264011 passed those tests but failed
RPM packaging on an empty debugsource file list. No test RPM was installed.

The next source layer supplies an owned IRQ transport and read-only CRMC table
loader. It remains disconnected from the running provider. A transaction uses
SWDRV0 only, never queues behind a wedged command, correlates the completion
with the resource in flight, and converts the 5000ms deadline to jiffies.
Timeout, wrong/stale/duplicate completion or loss of powered access masks the
owned Linux IRQ and preserves the first fault. Late completion cannot retry or
confirm the command. Unknown voter/status bits are not acknowledged.

The controller owner must retain power and mappings while the IRQ is owned.
Quiesce/release, suspend/resume and managed CCF integration are still required
before hardware admission. The transport currently has no teardown path and
must not be activated as a substitute for those lifecycle requirements.

The LUT loader propagates the first register/parent error and publishes no
partial table. It resolves the actual parent map through a read-only callback,
preserves integer HID semantics, and stops on the first duplicate/decreasing
frequency. CP0 is off; levels1 through7 are addressable by the three-bit PERF
protocol. The OEM loop also reads level8, although its vote path rejects that
index. The native loader never reads or exposes that unaddressable level.
Requests beyond the supported table return an error instead of silently
claiming an unattainable rate. Parent PLL/postdivider validation belongs to the
pending managed clock adapter.

The new COPR check retains the exact full12204 SRPM, original preparation and
profile. It runs the actual transport body with an MMIO/IRQ fault model, tests
every LUT read failure, uses the OEM ignored-read-error function as a negative
control, and compiles a real AArch64 object against the prepared kernel. These
checks are separate from future full provider and physical-camera acceptance.
The current firmware CRM guard and all sensor/calibration/focus gates remain.
