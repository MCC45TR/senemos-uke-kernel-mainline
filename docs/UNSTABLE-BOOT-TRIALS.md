# Isolated boot regression trials

4 November 2026. POCO Pad X1, Fedora Rawhide AArch64.

The withdrawn 7.3.1-6000 trial failed to start the desktop and returned to the
accepted 7.3.1-1500 slot. No persistent panic record was available. Its exact
failed instruction and the reset behavior have not been established.

The separate `senemos-uke-linux-kernel-mainline-unstable` family retains the
withdrawn source composition with a unique `-unstable` module ABI. It owns only
its prefixed profile link. Its packages have no automatic activation scriptlet
and preserve the ordinary family's selected profile and installed modules.

The first diagnostic stage skips the new CAMCC and front EEPROM boot graph
conversions. The second enables the CAMCC conversion while keeping front GENI
and EEPROM activation disabled. All driver sources, object fixtures and the
effective kernel configuration are retained. These are controlled bisection
steps, not a replacement for complete calibrated cameras and rear focus.

Install an exact signed candidate with DNF. Verify the accepted state and the
explicit installed bundle with `uke-kernel-update check BUNDLE` before applying
that bundle through the guarded updater. Retain the accepted slot and the
documented fastboot recovery route. A source/build pass is not a boot result;
record the running release, acceptance state, journal and pstore separately
after each physical trial. Test one staged candidate at a time.
