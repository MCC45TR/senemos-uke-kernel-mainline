# Uke CDSP and pogo acceptance

4 November 2026. The cumulative baseline is 7.3.1-11003-unstable,
source 261d85e218906f78d37810db78a4aa80cd900067, COPR11260288. It retains
CDSP/pogo, RTC counter, display color, corrected networking, NFC wake ownership
and CAMCC stage 1. Its 824 module signatures and tampered/unsigned/wrong-key
controls pass. Independent complete OpenPGP/header/payload checks of all six
RPMs match the installed package identities. Exact CDSP/pogo sources, module
ABI, firmware/OF aliases and critical config match. Artifact identities are in
manifests/cdsp-pogo11003-rpm-audit.json. Builds and package audits do not establish
secure-world, DMA, compute, keyboard or touchpad acceptance.

The shared cumulative kernel coordinator owns revision reservation, full COPR
kernel builds, kernel delivery/profile selection and reboot. The standalone
CDSP/pogo producer and installer are retired. Preserve every cumulative config,
DT, firmware namespace and hardware admission gate. Automatic seamless staging
stays enabled. Preserve the selected local rollback preference across upgrades
and reinstalls; package defaults remain rollback-enforced. Stable-family updates
require the user's explicit direction after physical qualification.

CAMCC remains quarantined with fault 5/unchecked. The camera goal still requires
both full cameras, fitted read-only EEPROM calibration and rear focus. Neither
this baseline nor CDSP/pogo testing closes that goal or any risk/case record.

Run tests/cdsp-pogo-device-report.sh for bounded read-only inventory. It reads no
authentication bytes and starts no remote processor or accessory operation.

## Device-local firmware and TEE client

The original native uke-cdsp-pogo-firmware helper reads fixed stock files through
read-only Uke UFS descriptors. Complete current CDSP metadata and the reconstructed
nine-part 147,544-byte TA are pinned to independent native and mtools/readelf
measurements. The 82,740-byte MCU retains its exact whole-file identity. Source
OTA version remains unidentified; exact source hashes are recorded in the support
component's manifests/current-stock-identities-20261104.json. No OEM firmware or
calibration enters Git or COPR. Signature/loader acceptance remains separate.

Helper 0.2-5 and provider 0.1-3 pass COPR11260265/11260266, complete signed-package
checks, DNF installation and read-only stock preflights. Normal --import and
--import-auth target a non-running installed unstable ABI; prepare future
cumulative candidates after DNF installation and before reboot. Automatic
seamless staging remains enabled throughout.

Helper 0.2-6, COPR11260713, adds --provision-idle-current for the exact audited11003
source after it has booted without these files. It requires native CDSP offline,
exact pogo unbound and no CDSP FastRPC endpoint. Those states are checked around
source acquisition. Existing families must match, and missing families publish
atomically without replacement. The command starts no DSP, MCU or TA. Native
filesystem fixtures exercise active/foreign/duplicate/missing consumer refusals.

The original C++ uke-pogo-auth provider admits the exact bound OF bridge, the
complete pinned TA and QTEE implementation4/OBJREF. It owns root/client/loader/app
objects, rejects TA errors and malformed/stale responses, and wipes secrets.
Its static manual service does not register a second system RPMB/FS listener.
Secure-world execution is not bounded by the userspace deadline; any required
qualified system listener and actual token acceptance remain runtime gates.

## Physical qualification

CDSP requires secure startup, named interrupts, both admitted FastRPC contexts,
translated DMA and a bounded RPC/compute workload with an output comparison.
Device-node creation alone is not computation. A compatible DSP shell, fileservice
and program runtime are needed for the selected workload. Retain secure-channel
policy and SIDs0xc01/0xc02; do not enable guessed contexts or remote heaps.

Test normal stop/restart and retained mappings/resources on refused secure stop.
The permanent CDSP platform instance has no ordinary unbind and retains its PAS
module until reboot. Arbitrary dynamic OF/parent removal is outside that policy.

Pogo requires the exact keyboard specimen and measured attachment/authentication.
Exercise all keys/modifiers/media, buttons, candidate 21-byte/three-contact reports,
coordinate range and physical touchpad geometry before claiming full gestures.
Check Caps Lock, microphone mute and backlight 0-100 through standard HID/LED
interfaces. Kernel token-store success is separate from accessory acceptance.

Exercise detach while inputs are active, reconnect, lid/tablet state, suspend,
wake and pending authentication. Require no stuck inputs or stale token/output
replays. Measure idle/sleep power and actual voltage timing; bulk regulator array
order does not prove physical rail sequencing. The MCU remains awake in normal
operation until a measured idle-power policy is qualified.

The canonical records are the CDSP/pogo lessons dated 3 and 4 November 2026 in
uke-linux-docs/docs/lessons/. Keep source, COPR, package and physical results
separate; preserve the accepted kernel and recovery route.
