# Linux 7.3.4-2: package and boot acceptance

16 November 2026, POCO Pad X1. Full unstable build
[11332265](https://copr.fedorainfracloud.org/coprs/mcc45tr/uke-linux-unstable/build/11332265/)
from source `385b48931882104b35cda5fddd65affa5cbdef35` succeeds in 1966 seconds.
It retains the cumulative full28 hardware stack and produces the same six
runtime RPM names. The complete generated recipe matches the reviewed source.
All 831 module signatures pass, including unsigned, altered and wrong-key
refusals. Independent verification of the six published RPMs passes all twelve
signatures against the pinned unstable repository key.

Normal repository DNF installs the matched singleboot profile. The native
updater writes, synchronizes and reads back inactive slot A, preserving
accepted kernel 7.3.3-28 in B. A normal authenticated USB console requests the
reboot. Actual kernel 7.3.4-2 then boots A and reaches native accepted health
with no issues or pending slot switch. Both slot banners and successful flags
are observed. This does not promote the stable package family.

The native DRM query now reports VRR available, loaded minimum 30 Hz and upper
mode 144 Hz, with no saved minimum overriding the boot default. KDE visibility,
variable presentation cadence, flicker and physical sound remain separate
tests; the first observation is at the graphical login screen. The three ALS
IIO interfaces remain registered and readable; initial zero values do not
prove their response to changing illumination. Adaptive backlight policy
still requires the normal desktop session check.

The running configuration enables LIVEPATCH, mandatory module signatures,
SELinux and lockdown. SELinux is Enforcing, lockdown selects integrity, and
the dedicated public signing certificate is present in the builtin trusted
keyring. An actual signed livepatch load/transition is not yet qualified.
The camera still reports its retained CRM admission refusal; no frame is
claimed. Kernel RGB status is available, battery validity is true, I/O error
is zero and its initial state is off. Physical threshold events remain open.

Managed firmware helper12 is independently built, signed and DNF delivered;
it verifies this exact current tuple without starting a DSP, MCU or TA. Its
fresh-root path retains all existing ownership and refusal checks. The DTBO
payload RPM is also delivered, but physical A/B DTBO updates and the complete
fastboot installation remain separate work. Full OEM verified boot,
hardware-bound storage keys, encrypted resume and both cameras remain open.
