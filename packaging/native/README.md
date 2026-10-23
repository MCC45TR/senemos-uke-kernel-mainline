# Mainline display source profile

23 October 2026 source candidate: release 21 retains the enabled boot-derived
early framebuffer and stdout until MSM's existing firmware-aperture takeover.
Its backlight link is removed so simpledrm neither waits for nor blanks the
native panel backlight. The complete splash reservation and native panel
supplies/reset remain preserved. Actual FDT fixtures precede packaging; visible
continuity requires a separate recoverable tablet trial. No physical result is
inherited from the package build. The optional O82 laboratory tool uses the
verified stable platform DRM path so early DRM card numbering cannot select
the GPU by mistake; its experimental display run remains separately gated.

23 October 2026 source candidate: release 20 targets only
`qcom/sm7675-xiaomi-uke.dtb` and the native O82 overlay. The resolved profile
excludes foreign SoC suppliers, panels, fixed Ethernet, SATA, raw flash and
unrelated board controllers. It retains USB peripherals, the four root
filesystems, virtualization, firewall, diagnostics and the existing Uke
hardware/firmware guards. `NR_CPUS=8` follows Uke's eight-core topology.
The Uke DISPCC remains in `dispcc-sm8550.c`; its Kconfig dependency now admits
the existing Cliffs GCC without requiring a foreign GCC. The early module list
contains Uke providers, generic recovery interfaces and their dependencies;
the build rejects a missing dependency before creating the initramfs.
Package and recoverable tablet boot validation remain separate gates.

21 October 2026 upstream refresh: Linux 7.2.12-1 carries the release-17
98-patch Uke profile, disabled audio and guarded updater contract. The original
7.2.11 queue and device records remain historical evidence. Source preparation
and COPR results do not establish boot or physical acceptance of 7.2.12.

21 October 2026 source follow-up: release 17 retains release 16's nftables,
root-filesystem and inactive audio policy. It adds the retained root-selector
capability, a lasting guarded-updater dependency, an independent OEM SDP adapter
check and the current per-CPU USB workqueue API. The active adaptation has 98
patches. The [USB admission record](../../docs/USB-SDP-ADAPTER-2026-10-21.md)
keeps zero-current and electrical suspend unqualified. No automatic charging
profile, boot activation or physical acceptance is introduced by this source.

17 October 2026. The native O82 profile is part of
`senemos-uke-linux-kernel-mainline`; there is no separate native kernel package.
The root `make srpm` and `.copr/Makefile` use one specification and source
producer. `packaging/native/Makefile` remains a compatibility SCM entry pointing
to the same producer. EL2 work remains separate.

The current source RPM contains signed Linux 7.2.11 and 80 ordered Uke patches,
the ABL adaptation, native DPU/DSI patches, the exact O82-42 seven-mode overlay,
configuration, contract checks, source commit and asset hashes. Integer releases
use separate module paths: `7.2.10-29`, `7.2.10-30`, then `7.2.11-1` after the
upstream source update. Install-only packages do not obsolete
or overwrite a previous kernel build.

Release 2 restores the source-built boot tuple: Image, matching modules,
independent DTB/native overlay, and a kernel-only Android v4 boot container.
The dracut base is generated on the AArch64 build worker from original Fedora
packages. The 376 early modules follow the native56 inventory with PAS excluded;
PAS starts after the real root supplies OEM firmware. The native updater writes
only when its local configuration explicitly enables automatic updates. It keeps
the previous full image and validates readback. Release 4 passes signed COPR
artifact checks and normal persistent tablet boot; the earlier native56 boot
is separate evidence.

Commit `4eb69e5`, published as `feature/dnf-stock-abl-updates-20261015`, contains
a dracut and guarded boot-container producer. Release 2 integrates its source
with the current O82, SSC, Bluetooth and bounded CDC startup configuration.
Private initramfs files, firmware, credentials and
per-device calibration are not source inputs here.

Upstream Linux's MSM register generator
`drivers/gpu/drm/msm/registers/gen_header.py` has SHA-256
`81763fc03ea0ebf254ab7427af2113dc0c7c0d80dceab61232b6e371463d1f90`.
It converts upstream XML into register headers and is an unavoidable host-only
Python build dependency. No project Python or Python payload is supplied to the
tablet; package installation checks reject Python files and runtimes.

## PMIC and CPU thermal candidate, 18 October 2026

Release 3 introduces the source change; release 4 admits the exact OEM PMIC ADC graph through upstream ADC5 Gen3,
IIO, iio-hwmon and generic-adc-thermal. It exports 23 supported channels and
connects ten board thermistors to their existing thermal zones. Four private
charger scalers remain unexported; GLINK battery telemetry remains separate.
Processed voltage uses the IIO millivolt ABI, including the two divided-voltage
channels previously classified as temperature by the upstream table.

Thirteen OEM emergency cooling maps are connected to the three standard
cpufreq cooling devices. The OEM 110 degree junction triggers and respective
8/10 degree hysteresis remain unchanged. Vendor CPU pause is replaced by
frequency cooling; the complete OEM skin and BCL policy is not implemented.
The exact release 4 COPR bundle boots normally. Its 23 IIO channels, ten board
thermal consumers and thirteen CPU cooling bindings are present. The full
installation has 67 readable hwmon temperature inputs and 51 thermal zones,
including overlapping measurements. Software-emulated thermal events lower
all three CPU policy limits and the GPU cap; all emulation is cleared afterward.
Actual heat protection and sustained workloads remain unqualified.

Release 5 adds a tested SMP2P history guard: ordinary entry notifications cannot
replay asserted ADSP ready/handover edges. Both genuine restart transitions
still reset input history. COPR 11165033 passes signed artifact checks; DNF
delivery and boot-B readback pass. Bounded tablet traces confirm the corrected
edge handling. Subsequent normal KDE reboots reach the installed system; the
first release-5 boot follows a forced power cycle. Full shutdown remains open.

Release 6 adds the four previously excluded OEM charger/battery ADC scalers,
with signed current, standard mA/mC units and a distinct battery thermistor
binding. The graph retains all 27 OEM channels. Full-code arithmetic sweeps,
battery monotonicity and malformed-resource refusal fixtures pass on the host.
COPR and tablet acceptance remain separate gates.

Release 7 maps the exact OEM lid/table SMP2P entries to standard EV_SW input
devices. The kernel reads remote open/closed line state and ignores missing or
conflicting initial reports. It neither acquires SSC-owned GPIOs nor introduces
polling or a startup service. Host state/refusal tests and the exact OEM graph
pass; normal module startup and physical Linux switch events remain separate
tablet gates.

Release 8 combines these sensor changes with the separately reviewed bounded
O82 video AVR experiment. Host checks pass against the combined source.
The read-only module parameter defaults to zero; no connector capability or
qualified VRR range is advertised. Physical activation tests use the separate
[AVR procedure](../../docs/O82-VRR-EXPERIMENT.md) after package delivery.

Release 2 compiles the full kernel but fails the early-PAS guard because its
module inventory includes PAS. Release 3 is cancelled before repeating that
known packaging fault. Release 4 removes PAS from the early inventory and
keeps the fail-closed check. No failed bundle is installed on the tablet.

Combined release 8 passes signed COPR 11165188 delivery, boot-B readback and
normal KDE reboot. The Hall module and both input devices appear automatically; physical lid and rear
fold/unfold events pass through standard evdev, and logind tracks the lid.
All 27 PMIC channels appear in IIO, hwmon and the original KDE backend with
standard units. Internal charger temperature reads 31.29–31.41 °C with USB
power. Without USB power its near-zero input produces the OEM-clamped 0 °C,
which is not a measured ambient temperature. Independent conversion checks
pass; absolute calibration remains unqualified. Battery temperature
and signed current feedback values are readable. Cover display policy, closed
cover boot, calibration accuracy and real heat protection remain unqualified.
The included AVR code defaults off and lacks the standard CRTC property
attachment; activation testing remains a separate continuation.

The 18 October 2026 Bluetooth candidate translates the exact selected Uke UART
wake interrupt to the falling edge requested by its OEM driver. The upstream
wake-IRQ helper retains the DT trigger, so keeping the OEM level cell causes
repeated runtime-PM wakeups. Host FDT fixtures preserve the other IRQ cells and
reject foreign graphs. Standard Bluetooth LE and modular BNEP are enabled for
the original desktop services. Matched package, idle-IRQ and Bluetooth device
validation remain separate from these source checks.

A separate 18 October source correction removes only the exact unused legacy
VA scalar qcom,is-used-swr-gpio=1. Upstream OF interprets its suffix as a GPIO
specifier and incorrectly resolves value 1 to the interrupt controller. The
actual FDT helper preserves native compatibles and other values. This does
not enable audio or alter the SoundWire pinctrl reference; tablet warning
validation remains pending.

## Full Type-C source candidate, 18 October 2026

The versioned `usb-profile` now selects `typec-v1` for the next combined native
build. It connects UCSI/HOST, Gen1 and external DisplayPort through the exact
Uke PHY, WCD and clock graph. CDC defaults off; the matching root manager enables
it only after an explicit user request. The existing accepted peripheral kernel
remains the rollback. Source, build and device acceptance are separate; see
[the full-profile record](../../docs/USB-TYPEC-FULL-PROFILE-20261018.md) for the
source pins, interfaces, composition requirements and remaining physical gates.

Kernel24 development profile compiles the restricted Uke threshold and positive
FCC interfaces after host guard/transport checks and actual AArch64 OFF/ON
translation-unit checks. Compilation leaves runtime qualification disabled.
The helper's shipped profile is unqualified and admission services remain off;
no threshold/current write, voltage negotiation or physical charging result is
implied. Exact per-boot firmware, protocol, source, cable and protection evidence
remains necessary before control operations. Upstream Kconfig defaults stay off.

## Linux 7.2.11-3 source candidate, 18 October 2026

The79-patch queue adds a restricted one-shot application probe for the already
enabled70/80 charge band. Firmware receipt/readback leaves physical effect
unknown and prevents another fixed writer for that driver instance. General
control qualification remains closed. See the charging-control record.

The separately reviewed AudioReach changes from project commit693dfd4 are
ported to7.2.11 as patch0079. `audio-profile` defaults to `disabled`; optional
`services-only` supplies native APM/PRM ports while DAIs, SLIM and amplifier
buses remain disabled. It creates no sound card or playback/capture path.
The host-only preset inspector never ships in the target package. Source and
software checks do not qualify internal speaker or microphone operation.

## Audio firmware responses, 20 October 2026

The 7.2.11-12 source candidate adds patch 0084. PRM request/release basic errors
reach the existing synchronous DSP error path. APM basic replies are bounded,
and readiness errors must match the active nonzero query token. A successful
basic ACK still waits for the service-specific response. Actual-source GCC and
Clang sanitizer fixtures and AArch64 driver objects pass. The audio profile
remains disabled; full package, admitted firmware and physical audio validation
are separate. PRM stale-response correlation and graph/DMA lifetime remain open.
Patch 0085 also preserves unmap opcode/status, carries the existing buffer-type
token bit and clears only the selected mapping after firmware success. Host
callback checks do not qualify caller-side DMA recovery or graph lifetime.

Patch 0086 serializes PRM transactions with a completion and spinlock. Only
the pending nonzero token, expected opcode and resource parameter can complete
a request. Late/duplicate/unrelated replies cannot overwrite its result.
The module-wide 32-bit sequence survives device reprobe; wire wrap and module
reload are not an unlimited epoch guarantee. Exact firmware token echo and
callback teardown remain separate admission gates. Audio stays disabled.

### Transaction and buffer follow-up, 20 October 2026

Patches 0086–0092 extend the source candidate with correlated PRM replies,
graph payload/period bounds, dynamic-port callback draining, private receive
batches and a sleepable compressed-stream lock. Buffer producers preserve the
ring position after failed sends and carry advertised 128 KiB lengths in an
8-bit index/24-bit length host token. Invalid DMA replies do not publish normal
period progress. These changes introduce no firmware selector or board value.

Actual-source fault fixtures cover the previous failures and the corrected
paths under GCC/Clang ASan/UBSan. Full AArch64 driver objects compile with
`WERROR=1`. Static service/PDR teardown, period reuse/late DMA replies,
caller-side XRUN/error recovery and complete DMA ownership remain open.
Firmware token echo, fitted codec/amplifier, calibration/protection and physical
stream acceptance are separate gates; the native audio profile stays disabled.

Patch 0093 returns graph OPEN errors, retains failed IDs within the current
provider instance and cleans that local metadata at removal. First publication
and final release use the existing provider command mutex; lookups cannot
resurrect a zero reference. This does not establish remote cleanup after a
timeout or a new firmware epoch after manual driver rebind.

Patch 0094 adds the native service quiesce boundary and serialized callback
publication/removal. APM blocks new opens and drains service callbacks before
topology release. PRM releases its children and drains the serialized request
before rejecting further work and disabling callbacks. Process-context and
driver-order fixtures pass; transport/PDR teardown, remote ownership and full
DMA/XRUN recovery remain separate gates. No sound card or route is enabled.

20 October 2026 userdata image refresh: release14 retains source12's94-patch
hardware queue and disabled native audio profile. It restores the explicit
linux/EXT4 and userdata/F2FS root selector from source87eadc3. F2FS and its
security labels are built in; a userdata boot container carries only the bounded
root-profile selector. The current USB/offline-charge paths remain present.
Source tests and package builds do not establish userdata boot acceptance.

## Cliffs7 cache package candidate, 20 October 2026

Release 15 retains release 14's first 94 patch hashes, root profiles, Type-C,
charging and thermal paths. Patches 0095–0097 add the four-bank/v5 Cliffs7
cache provider, five-window binding and managed GPU supplier ordering.
The hashed `llcc-profile` selects `native-v1` during native source preparation;
the generated boot helper transforms only its private admitted DT copy.
Unknown profiles and source/graph mismatches are refused. Audio stays disabled.

The reviewed root selector also forwards exact `_a`/`_b` boot-slot identity and
an explicit `msm.o82_vrr_test_min_hz=0|30` only with the userdata root selector.
Duplicates, malformed values, forced-argument conflicts and insufficient space
are rejected before command-line mutation. Other bootloader arguments remain
excluded. The standard Linux container does not enable the VRR experiment.

The local source RPM passes fresh 97-patch preparation and three native
AArch64 objects with KCFLAGS=-Werror. These results remain separate from a
full kernel/package build and tablet acceptance. Actual bank/version
admission, partial-programming recovery, GPU lifetime, cache coherency,
suspend and any performance gain remain unqualified. Keep the accepted kernel
and its matched modules available for recovery.

## Native firewall and root policy candidate, 20 October 2026

Release 16 retains the 97-patch hardware queue and adds the modules required
by the original firewalld nftables backend: mixed IPv4/IPv6 tables, connection
tracking, NAT, masquerading, redirection, rejection, rate limits, logging and
FIB lookup. Source and resolved-configuration checks pass; package checks also
require the corresponding built modules. This does not establish a running
tablet firewall or change network rules during an SSH session.

The forced command-line parser selects only `rootfstype=ext4` for the Linux
profile or `rootfstype=f2fs` for userdata. Userdata changes `panic=0` to
`panic=10`; Linux retains its bring-up setting. Duplicate or changed forced
defaults are refused before mutation. Embedded dracut defaults exclude these
fields so they cannot override the selected profile. GCC and Clang ASan/UBSan
fixtures cover both profiles, all field orders, rejected input and capacity
boundaries. A panic restart is separate from hard-hang recovery or physical
A/B rollback qualification. No tablet installation or reboot is implied.

## Audio service registration, 22 October 2026

The 7.2.12-10 candidate selects the existing `services-only` audio profile.
Native APM/PRM services 1/2 can bind and perform the bounded firmware readiness
query; original clients 3/7 remain present. Both DAI children, amplifier I2C
and SLIM remain disabled. The package does not create playback/capture paths
or apply microphone bias, amplifier presets or calibration. The existing
`disabled` preparation setting remains available for rollback/source comparison.
Host FDT and actual-source response/lifetime checks precede COPR submission.
Tablet service binding and physical internal audio remain separate tests.

## Audio card registration candidate, 22 October 2026

The 7.2.12-14 source selects `registration-only`: the native APM and PCM
components register a Uke card with playback/capture frontend descriptions.
The displayed names explicitly mark streams disabled. The q6apm component
refuses both PCM and compressed opens before DSP graph allocation, rather
than relying on the later machine startup callback. It also skips PCM buffer
construction and teardown mappings, which source review found unguarded in
the uninstalled release-12 candidate. No backend, amplifier,
microphone bias or SLIM path is enabled. Native card visibility and physical
audio acceptance remain separate results.

Release 13 registered the card after a manual module load on the tablet, but
cold autoload failed through the original Fedora ALSA rule's missing
`snd-seq` dependency. Its frontend IOMMU attachment also triggered warnings
outside the guarded boot scope. Release 14 includes the sequencer module and
omits that attachment while frontend DMA remains prohibited. The original
Fedora rule and SMMU guard are retained; cold-boot validation is still required.

Original host `alsatplg` from Fedora `alsa-topology-utils` compiles the project frontend
description; no donor build script is executed. The output contains no
calibration, graph endpoint or mixer and is installed below the exact kernel
release's firmware search directory. The host ACDB metadata inspector and its
fixtures are source/build tools only and do not enter tablet payloads.
