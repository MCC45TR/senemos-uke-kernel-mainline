# SM7675 native receive graph contract

17 November 2026. The tablet runs accepted full8/B with CAMCC ready and runtime
suspended. Its native front bus, sensor and aggregate CAMSS graph remain
inactive. The following source and read-only live-DT comparison prepares the
next receive-path work; it does not establish a camera frame or authorize
unqualified resource activation.

## Register resources

The selected DT's node unit addresses differ from several actual `reg`
properties. Native resources must follow the checked register tuples.

| Resource | Physical register origin | Size |
|---|---|---|
| CSID0/1/2 | 0x0acb8000 / 0x0acba000 / 0x0acbc000 | 0xd00 each |
| Shared CSID wrapper | 0x0acb6000 | 0x1000 |
| CSID lite0/1 | 0x0accb000 / 0x0acd0000 | 0xa00 each |
| VFE0/1/2 | 0x0ac62000 / 0x0ac71000 / 0x0ac80000 | 0xf000 each |
| Native VFE lite0/1 | 0x0accc000 / 0x0acd1000 | 0x1800 each |
| CSIPHY0 through 4 | 0x0ace4000 through 0x0acec000, step 0x2000 | 0x2000 each |

The native lite VFE ranges above are derived from the OEM combined 0x2800-byte
resource and its source-defined +0x1000 VFE origin. This separates CSID and VFE
ownership and agrees with the native gen3 offsets. The exact Uke GPL
`cam_vfe_lite86x.h` selects the shared lite88x bus registers. Source27 qualifies
its [two required programming differences](CAMSS-LITE734.md).

The IFE SMMU description selects stream 0x800 with mask 0x20. A native graph
must resolve the original IOMMU provider and retain its translation and 32-bit
DMA constraints. ISP/ICP/JPEG/CRE contexts are separate resources. The IRQ,
clock, power-domain and interconnect tuples still need complete aggregate
validation and their own source/build checks.

## Shared PHY supply limits

All five selected PHY descriptions use the same supplies and limits:

| PHY supply | Consumer voltage range | Declared load |
|---|---|---|
| pmxr2230 L2B, CSI 0p9 | 880000–912000 microvolts | 98480 microamps |
| pmxr2230 L4B, CSI 1p2 | 1200000 microvolts | 17920 microamps |

The L2B provider itself allows 880000–950000 microvolts. Its declared consumers
also include the display PHYs, USB PHYs, DisplayPort and UFS reference supply.
These are static DT limits and connections; the physical voltage was not
measured or changed.

The reviewed Linux 7.3.4 `camss-csiphy.c` bulk-enables the supplies without a
per-consumer voltage request. The existing Uke resource descriptor supplies
the load values but does not yet impose the narrower CSI voltage range.
Native activation therefore needs a demand-based consumer constraint before
enable. It must respect concurrent consumers, unwind failed acquisition and
release its own vote only after successful power-off. A failure must preserve
the resources needed for safe recovery. Idle camera ownership must not block
the other consumers' valid operating ranges.

The [source28 supply lifecycle](CAMSS-PHY-POWER734.md) prepares this change;
its COPR qualification and the built-in runtime profile remain separate gates.

The selected PHY0 compatible is `qcom,csiphy-v2.2.1-n16t`; PHY1–4 select ordinary
2.2.1. The existing front PHY4 helper does not establish the rear PHY0 variant.
Both cameras and all supported modes remain in scope.

## Bandwidth and sensor admission

The existing native Cliffs interconnect extension explicitly admits the
display route. It does not yet declare `qnm_camnoc_hf`. The Uke GPL
`drivers/interconnect/qcom/cliffs.c` defines both HLOS and camera-specific
voters. Their correct ownership, QoS and BCM route must be resolved before the
aggregate CAMSS `hf_mnoc` dependency can be supplied. The static CPAS
`cam_ahb` path alone does not complete that contract.

The sensor address, fitted identity, lane mapping and complete board supply
lifecycle remain unknown. The generic front DT client and an adjacent-board
driver's probe list do not establish those facts. Future source/object and
binding checks precede a cumulative signed kernel, DNF delivery, native graph
observation and completed buffers. Private fitted calibration remains read-only;
rear focus and full OEM capability remain open.

The [MiCode sensor comparison](CAMERA-MICODE-SENSORS734.md) records the
additional GPL OV08D10 driver, its address convention and board power limits.

The implementation sources are the pinned Uke GPL kernel
`5712080a4b0c0b1a879e6d145c601c649ddaddfd`, Uke GPL camera driver
`699fa15a98abd40fbb94f3a6fc00f91723d29d35`, applicable same-SoC OnePlus GPL
sources and native Linux 7.3.4 at `7595a62d45ee1a2297eafa5f2ef5d0a45142d84d`.
The published camera-DT overlay with unidentified license is not a new code
donor. No closed HAL parameters or calibration bytes are used by this work.
