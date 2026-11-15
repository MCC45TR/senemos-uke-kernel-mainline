/* SPDX-License-Identifier: GPL-2.0-only */
/* Codec mutex held. Keep VI/PLL transport alive while the DSP drains STOP. */
static int fs19xx_mute_transport(struct fs19xx_priv *fs19xx)
{
	unsigned int value;
	int ret;

	if (!fs19xx->powered)
		return 0;
	ret = fs19xx_read_stable(fs19xx, FS19XX_REG_DACCTRL, &value);
	if (ret)
		return ret;
	ret = regmap_write(fs19xx->regmap, FS19XX_REG_DACCTRL,
			   value | FS19XX_DACCTRL_MUTE_BIT);
	if (ret)
		return ret;
	ret = fs19xx_read_stable(fs19xx, FS19XX_REG_DACCTRL, &value);
	if (ret)
		return ret;
	if (!(value & FS19XX_DACCTRL_MUTE_BIT))
		return -EIO;
	fs19xx->unmuted = false;
	fs19xx->pll_polls = 0;
	/* The existing bounded guard wait stops hardware if DSP STOP stalls. */
	mod_delayed_work(system_percpu_wq, &fs19xx->unmute_work,
			 msecs_to_jiffies(FS19XX_LOCK_POLL_MS));
	return 0;
}
