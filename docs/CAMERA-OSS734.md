# Camera source admission on Linux 7.3.4

17 November 2026. Camera development continues from published, licensed open
source implementations. Accepted full8/B has passed native CAMCC admission
and idle release. Source27 and source30 qualify further receive-path changes;
the bus, sensor and aggregate graph remain inactive. These source/object
results do not establish camera operation on Uke.

| Source and exact revision | License and attribution | Useful contract and limit |
|---|---|---|
| [Uke OEM kernel](https://github.com/MiCode/Xiaomi_Kernel_OpenSource/tree/5712080a4b0c0b1a879e6d145c601c649ddaddfd), `drivers/soc/qcom/crm.c` | GPL-2.0-only; Qualcomm Innovation Center | Primary CRM transport and layout evidence used by native22. Preserve firmware ownership and the characterized clock/voltage limits. |
| Same-SoC [OnePlus kernel](https://github.com/OnePlusOSS/android_kernel_oneplus_sm7675/tree/fc892483f1d61f245924681eb5abd563564d9cba), `drivers/soc/qcom/crm.c` | GPL-2.0-only; Qualcomm Innovation Center | Independent same-SoC comparison. Its board wiring and power policy are not Uke values. |
| [Uke camera driver sources](https://github.com/MiCode/vendor_qcom_opensource_camera-kernel/tree/699fa15a98abd40fbb94f3a6fc00f91723d29d35), `drivers/cam_sensor_module/cam_sensor_utils/cam_sensor_util.c` and CSIPHY 2.2.1 sources | GPL-2.0-only; Linux Foundation and Qualcomm Innovation Center | Native supply validation, I2C/CCI address conventions and shared PHY programming. The generic sensor framework accepts a separate probe contract; it does not identify the fitted sensor. |
| [Linux 7.3.4](https://github.com/gregkh/linux/tree/7595a62d45ee1a2297eafa5f2ef5d0a45142d84d), `drivers/media/i2c/ov08d10.c` | GPL-2.0; Intel | Existing native candidate: two lanes, 19.2/24 MHz input clocks, 360/720 MHz link frequencies, three supplies and masked chip identification. These supported choices do not establish Uke wiring or fitted identity. |
| Same Linux revision, `Documentation/devicetree/bindings/media/i2c/ovti,ov08d10.yaml` | GPL-2.0-only OR BSD-2-Clause | Sensor graph, clock, reset GPIO and supply description. An example address or lane mapping is not board evidence. |
| Same Linux revision, `drivers/reset/core.c` and `drivers/regulator/fixed.c` | GPL-2.0-or-later | Reset-control lookup supports the `reset-gpios` fallback. The fixed-regulator driver owns the enable GPIO. Both dependencies already exist in the cumulative configuration. |
| [Rockchip OV08D10](https://github.com/rockchip-linux/kernel/blob/77168c8d5ab82399f65a80e9f807b50ba37cf483/drivers/media/i2c/ov08d10.c) | GPL-2.0; Rockchip Electronics | Independent sensor comparison agrees on the 0x5608 ID at byte registers 0/1. Its modes require 24 MHz; no Rockchip power sequence, clock setting or board GPIO is selected for Uke. |
| [MiCode OV08D10 module](https://github.com/MiCode/mtkcam-kernel_device_modules/blob/bfd3e45948f5c1e1307ef6e217960596a08c5f61/imgsensor/src-v4l2/common/duchampov08d10ultra_mipi_raw/duchampov08d10ultramipiraw_Sensor.c), plus `kd_imgsensor.h` in `MTK_kernel_device_modules` at `3c4ccd07d5624879555ec710c11bb8818e5cb5c6` | GPL-2.0; MediaTek | Independent 0x5608 ID and 8-bit `0x6c/0x20` to native `0x36/0x10` conversion. Duchamp power/clock settings are not Uke board evidence; see the [complete comparison](CAMERA-MICODE-SENSORS734.md). |

The exact Uke OEM kernel also contains the Intel OV08D10 driver. A bounded
search of its arm64 configuration and DT sources did not establish its
selection for Uke. Likewise, the reviewed upstream and public patch searches
did not find an independent complete SM7675 CAMSS graph or an OSS Uke sensor
probe/mode table. These are search limits, not proof that none exists.

Address interpretation requires the complete downstream call chain.
`cam_sensor_update_i2c_info()` stores the probe address directly in the QUP
I2C client, but `cam_sensor_io/cam_sensor_qup_i2c.c` shifts that stored value
right by one when constructing both read and write `i2c_msg` addresses.
CCI performs its shift when assigning the SID. Reading only the earlier
client assignment would therefore give the wrong native Linux address
convention. This establishes a conversion rule, not a fitted Uke address.

The [author's OV08D10 v2 series](https://lore.kernel.org/linux-media/20261024-ov08d10-get-selection-v2-0-f8c49972ca18@leica-geosystems.com/)
remains relevant to geometry and active-state handling. The cumulative kernel
already carries the adapted probe-debug fix and exposure-read error checks.
The separately prepared geometry patch is not implied to be installed.

## Remaining board evidence

Read-only observation of the currently selected Uke DT identifies front GENI8,
MCLK4 and a fixed front AVDD regulator whose enable GPIO is 160. This corrects
the older GPIO78 note. No GPIO or regulator was changed during that observation.
The published Uke camera-DT checkout has no identified file/repository license
for its sensor overlay; it is not admitted as an OSS code donor merely because
its source is public. No new implementation is copied from that overlay.

The fitted sensor/address, physical lane map and the complete dependency and
power sequence still need admissible evidence. In particular, the generic
three-supply driver does not explain every extra supply in the inherited board
description. Upstream example values, another board's settings and closed-HAL
parameters cannot fill these gaps. Subsequent device checks must use an
admitted native driver and its documented lifecycle.

Full8 has since passed native CAMCC admission and idle release on two normal
boots; see [its measured scope](CAMERA-FULL7348.md). The next
[lite VFE source review](CAMSS-LITE734.md) passed source/object qualification;
the [demand-scoped PHY supplies](CAMSS-PHY-POWER734.md) also passed source/object
qualification. The [aggregate graph contract](CAMSS-GRAPH734.md) remains under investigation. Enabling the
sensor/media graph, completing RAW buffers, consuming private read-only fitted
calibration and providing both cameras with rear focus remain separate work.
Original Fedora media/desktop packages and the existing signed RPM/DNF delivery
and recovery flow remain in use.
