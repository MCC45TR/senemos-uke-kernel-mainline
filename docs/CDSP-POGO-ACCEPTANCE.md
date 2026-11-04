# Uke CDSP and pogo acceptance

4 November 2026. Source and COPR results are engineering evidence; hardware
acceptance remains open. New development uses the unstable package family and
an -unstable ABI. The current producer retains the exact installed7300 source,
including its disabled unqualified secure RTC path and recovery/DNF policy.
No native compilation runs on the tablet.

Historical kernel7.3.1-2313, COPR11252339, passes complete native checks, including833
module signatures and tampered/unsigned/wrong-key refusals. Independent checks
verify both OpenPGP signatures and header/payload digests of all six RPMs.
The separate firmware helper0.1-2 succeeds in COPR11252345 and passes the same
RPM checks. These normal-family artifacts are not deployment targets under the
4 November policy. The new retained7300 producer is
packaging/native/copr-cdsp-pogo-unstable.sh. Its complete binary and package
results must be checked separately.
The COPR request pins CDSP_POGO_RPM_REVISION explicitly; the producer retains
the global published-release guard and bounds the short ALSA driver identity.

Run tests/cdsp-pogo-device-report.sh for a bounded read-only inventory. It never
starts remoteproc, uploads firmware, reads authentication attributes or writes
LED/input controls.

The historical packaging/native/deliver-cdsp-pogo-candidate.sh now refuses
execution. Deliver signed matching unstable packages through DNF after reviewing
current/staged cohorts. Keep automatic activation disabled, retain the existing
singleboot selection and accepted recovery route, and do not request a reboot
as part of package installation. Later source changes need explicit composition.

The separately packaged native helper uke-cdsp-pogo-firmware --preflight
checks fixed stock CDSP and MCU files without publishing or starting devices.
Both source partitions are read-only views of the observed Uke UFS LUNs.
After matching kernel installation, --import KERNEL_RELEASE publishes only
versioned families for a non-running kernel. Exact MDT identity must pass;
never relax hashes after an unexplained refusal. No OEM bytes enter COPR.
The helper0.2-2 VFAT correction passes COPR11260014 and is installed through DNF.
Device preflight now resolves the fixed stock names but refuses differing CDSP
and complete authentication-image identities. Investigate those differences
before importing firmware; no unrecognized image is admitted.

CDSP acceptance requires matched device-local cdsp.mdt/cdsp_dtb.mdt and all
requested split segments under qcom/uke/cdsp. Their redistribution/provisioning
is separate from the kernel RPM. Confirm the running matched kernel/module
cohort before a controlled remoteproc start. Automatic boot is disabled.
Record secure startup, named interrupts, both FastRPC contexts, translated DMA,
a bounded buffer/RPC workload and output comparison. Device-node creation alone
does not establish computation. A compatible DSP shell, fileservice and program
runtime are required for the chosen workload.

Test normal stop/restart and confirm mappings and client resources remain held
if secure shutdown fails. The permanent CDSP driver has no normal unbind path
and keeps its shared PAS module loaded. Arbitrary dynamic parent/OF removal is
outside this bounded lifetime policy. Preserve the existing recovery route.

Pogo acceptance requires the exact Focus keyboard specimen/model and the
hash-admitted Global304 MCU RAM image under qcom/uke/nanosic. No other-board
image is a substitute. Provisioning is device-local; no OEM image is in this
source or COPR payload. The driver validates it before GPIO/power activity.

Record attachment, all key/modifier/media press/release paths, three-contact
candidate reports, buttons and coordinate range. Establish the exact report
layout and physical touchpad geometry before claiming complete gestures.
Check Caps Lock, backlight0-100 and microphone LED requests through the standard
HID/LED interfaces. The separate original C++ uke-pogo-auth0.1-2 provider passes
COPR11259992, complete signed-package checks and DNF installation. It refuses
operation on the current kernel without the exact bound authentication bridge.
Its static service remains inactive. Exact Uke TA/challenge and accessory
acceptance remain open; token submission is separate from confirmed authentication.

Exercise detach/reconnect while keys or contacts are active, lid close/open,
tablet fold state, system sleep/wake and pending authentication. Confirm there
are no stuck inputs or stale output/token replays. Compare passive power with
no accessory, attached idle and sleep. The current driver keeps the MCU awake
during ordinary operation; idle-power optimization needs measured qualification.

Document physical results independently of synthetic fault injection and
compilation. The canonical engineering record is
uke-linux-docs/docs/lessons/2026-11-03-UKE-CDSP-POGO-KERNEL.md.
The unstable/provider follow-up is
uke-linux-docs/docs/lessons/2026-11-04-UKE-CDSP-POGO-UNSTABLE.md.
