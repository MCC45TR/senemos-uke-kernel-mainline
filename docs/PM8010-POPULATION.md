# Optional PM8010 population on Uke

31 October 2026. On POCO Pad X1 with Fedora Rawhide and Linux7.3.1-3, the
inherited PM8010 N node at SID0x0d fails its revision read at0x104. The
firmware PMIC inventory does not advertise model65 (PM8010), the command DB
has no PM8010 N regulator resources, and the exact OEM camera profile uses
other suppliers. The other six declared primary-bus PMIC devices bind.
These observations identify a selected-profile population mismatch; DT names
alone do not establish the physical chip inventory.

The correction checks only the exact Uke PM8010 N node before transport
access. A bounded and complete SMEM inventory without PM8010, together with
a ready command DB without any ldon1 through ldon7 resource, returns an
unpopulated-device result. Populated variants, another board or another
node keep ordinary probing. Missing, malformed and deferred metadata are
errors, never evidence of absence. The change does not alter generic SPMI
errors, fabricate a revision, remove a thermal declaration or write a
power/reset register.

The source owner retains the original Linux Foundation/Qualcomm MFD
attribution. Uke OEM kernel `5712080a`, DT `94c84aeb` and camera DT
`57d2135e` were compared with the pinned OnePlus SM7675 and Palawan/Lamma
references and current upstream. Reference-board PM8010 regulator wiring
is not copied. The recent upstream PM8010 I2C frontend is a separate bus
implementation.

Fresh7.3.1-4 retains the verified7.3.1-3 native profile and its exact
122-patch adaptation. Source/native/package verification and a real boot
remain separate gates. The actual helper fixtures cover population,
all seven resource alternatives, foreign nodes, deferred firmware and
malformed boundaries. Physical acceptance is pending.
