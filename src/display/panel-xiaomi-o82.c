// SPDX-License-Identifier: GPL-2.0-only
/*
 * Experimental Xiaomi Pad 7 O82 dual-DSI panel candidate for Linux 7.2.9/7.2.10.
 * Not activated by the supported build or DTBO. Hardware unvalidated.
 * Lifecycle based on the archived O82 draft and upstream nt35950 pattern.
 * Based on linuxgamer/uke-fedora cf4f9317a7fef3e9bdddc36bedcb257fa51b0994.
 * OEM packet types, delays, timing groups and power sequence are retained.
 */
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_graph.h>
#include <linux/regulator/consumer.h>
#include <drm/display/drm_dsc_helper.h>
#include <drm/drm_connector.h>
#include <drm/drm_crtc.h>
#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>
#include <video/mipi_display.h>

struct o82_command {
	u8 type, last, channel, downstream_flags, delay_ms;
	u16 len;
	const u8 *data;
};

struct o82_profile {
	const struct o82_command *on;
	unsigned int on_count;
	const struct o82_command *switch_commands;
	unsigned int switch_count;
	const struct o82_command *off;
	unsigned int off_count;
};
struct o82_timing {
	unsigned int group;
	struct drm_display_mode mode;
};
#include "o82-data.h"

struct o82_panel {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi[2];
	struct drm_dsc_config dsc;
	struct regulator *supplies[3];
	struct gpio_desc *reset;
	struct drm_connector *connector;
	const struct o82_profile *profiles, *active;
	unsigned int enabled_supplies;
	unsigned int loaded_supplies;
	bool reset_output;
	bool prepared;
	bool initial_60hz_only;
};

static int o82_send(struct o82_panel *ctx, const struct o82_command *cmd, bool lpm)
{
	struct mipi_dsi_msg msg = {
		.channel = cmd->channel,
		.type = cmd->type,
		.flags = lpm ? MIPI_DSI_MSG_USE_LPM : 0,
		.tx_len = cmd->len,
		.tx_buf = cmd->data,
	};
	int i;
	ssize_t ret = 0;

	/* OEM flag 0x40 batches commands, not ACK. Serialize instead. In MSM
	 * sync mode DSI0 writes are acknowledged without transmission; DSI1
	 * triggers both links. Sending to both also supports non-sync hosts.
	 */
	for (i = 0; i < ARRAY_SIZE(ctx->dsi); i++) {
		struct mipi_dsi_host *host = ctx->dsi[i]->host;

		ret = host->ops->transfer(host, &msg);
		/* MSM returns padded DMA packet bytes; other hosts return payload bytes. */
		if (ret < cmd->len) {
			dev_err(&ctx->dsi[i]->dev,
				"O82 transfer failed: link=%d type=%#x opcode=%#x len=%u lpm=%d result=%zd\n",
				i, cmd->type, cmd->data[0], cmd->len, lpm, ret);
			if (ret >= 0)
				ret = -EIO;
			break;
		}
	}
	/* A failed transfer may have reached the panel: preserve settle delays. */
	if (cmd->delay_ms)
		msleep(cmd->delay_ms);
	return ret < 0 ? ret : 0;
}

static int o82_off(struct o82_panel *ctx)
{
	int i, ret, first_error = 0;

	for (i = 0; i < ctx->active->off_count; i++) {
		ret = o82_send(ctx, &ctx->active->off[i], true);
		if (ret && !first_error)
			first_error = ret;
	}
	return first_error;
}

static int o82_power_off(struct o82_panel *ctx)
{
	int i, ret, first_error = 0;

	if (ctx->reset_output)
		gpiod_set_value_cansleep(ctx->reset, 0);
	for (i = ARRAY_SIZE(ctx->supplies) - 1; i >= 0; i--) {
		if (ctx->enabled_supplies & BIT(i)) {
			ret = regulator_disable(ctx->supplies[i]);
			if (ret && !first_error)
				first_error = ret;
			if (!ret)
				ctx->enabled_supplies &= ~BIT(i);
		}
		if (!(ctx->enabled_supplies & BIT(i)) && (ctx->loaded_supplies & BIT(i))) {
			ret = regulator_set_load(ctx->supplies[i], 0);
			if (ret && !first_error)
				first_error = ret;
			if (!ret)
				ctx->loaded_supplies &= ~BIT(i);
		}
		msleep(2);
	}
	return first_error;
}

static int o82_prepare(struct drm_panel *panel)
{
	struct o82_panel *ctx = container_of(panel, struct o82_panel, panel);
	struct drm_dsc_config pps_config;
	struct drm_dsc_picture_parameter_set pps;
	const struct o82_command pps_cmd = {
		.type = MIPI_DSI_PICTURE_PARAMETER_SET,
		.len = sizeof(pps), .data = (const u8 *)&pps,
	};
	int i, ret;
	const struct drm_display_mode *mode;
	const struct o82_profile *profile = NULL;

	if (!ctx->connector || !ctx->connector->state ||
	    !ctx->connector->state->crtc || !ctx->connector->state->crtc->state) {
		dev_err(&ctx->dsi[0]->dev, "O82 prepare has no active connector state\n");
		return -EINVAL;
	}
	mode = &ctx->connector->state->crtc->state->adjusted_mode;
	for (i = 0; i < ARRAY_SIZE(o82_modes); i++)
		if (drm_mode_equal(mode, &o82_modes[i].mode)) {
			profile = &ctx->profiles[o82_modes[i].group];
			break;
		}
	if (!profile) {
		dev_err(&ctx->dsi[0]->dev, "O82 prepare mode rejected: %dx%d clock=%d htotal=%d vtotal=%d\n",
			mode->hdisplay, mode->vdisplay, mode->clock, mode->htotal, mode->vtotal);
		return -EINVAL;
	}

	if (ctx->prepared)
		return ctx->active == profile ? 0 : -EBUSY;
	if (ctx->dsc.pic_width != 3200 || ctx->dsc.pic_height != 2136 ||
	    ctx->dsc.slice_width != 800 || ctx->dsc.slice_height != 24 ||
	    ctx->dsc.rc_model_size != 8192 || ctx->dsc.initial_dec_delay != 690 ||
	    ctx->dsc.first_line_bpg_offset != 13 ||
	    ctx->dsc.rc_range_params[0].range_max_qp != 8)
		return -EINVAL;
	/* Do not accumulate enable references after a failed power-down. */
	if (ctx->enabled_supplies || ctx->loaded_supplies)
		return -EBUSY;
	ctx->active = profile;
	for (i = 0; i < ARRAY_SIZE(ctx->supplies); i++) {
		ret = regulator_set_load(ctx->supplies[i], 300000);
		if (ret < 0) {
			dev_err(&ctx->dsi[0]->dev, "O82 supply[%d] load failed: %d\n", i, ret);
			goto rollback_supplies;
		}
		ctx->loaded_supplies |= BIT(i);
		ret = regulator_enable(ctx->supplies[i]);
		if (ret) {
			dev_err(&ctx->dsi[0]->dev, "O82 supply[%d] enable failed: %d\n", i, ret);
			goto rollback_supplies;
		}
		ctx->enabled_supplies |= BIT(i);
		msleep(2);
	}
	/* ASIS at probe preserves splash; establish direction before first toggle. */
	ret = gpiod_direction_output(ctx->reset, 0);
	if (ret) {
		dev_err(&ctx->dsi[0]->dev, "O82 reset direction failed: %d\n", ret);
		goto rollback_supplies;
	}
	ctx->reset_output = true;
	msleep(10);
	gpiod_set_value_cansleep(ctx->reset, 1);
	msleep(3);
	gpiod_set_value_cansleep(ctx->reset, 0);
	msleep(3);
	gpiod_set_value_cansleep(ctx->reset, 1);
	msleep(15);
	for (i = 0; i < profile->on_count + profile->switch_count; i++) {
		const struct o82_command *cmd = i < profile->on_count ?
			&profile->on[i] : &profile->switch_commands[i - profile->on_count];
		/* OEM on/off sequences use LP; timing-switch video commands use HS. */
		ret = o82_send(ctx, cmd, i < profile->on_count);
		if (ret) {
			dev_err(&ctx->dsi[0]->dev, "O82 prepare command[%d] failed: %d\n", i, ret);
			o82_off(ctx);
			o82_power_off(ctx);
			return ret;
		}
	}
	/* OEM PPS describes each link; DPU keeps the shared 3200-pixel frame. */
	pps_config = ctx->dsc;
	pps_config.pic_width /= ARRAY_SIZE(ctx->dsi);
	drm_dsc_pps_payload_pack(&pps, &pps_config);
	ret = o82_send(ctx, &pps_cmd, true);
	if (ret) {
		o82_off(ctx);
		o82_power_off(ctx);
		return ret;
	}
	ctx->prepared = true;
	return 0;

rollback_supplies:
	o82_power_off(ctx);
	return ret;
}

static int o82_unprepare(struct drm_panel *panel)
{
	struct o82_panel *ctx = container_of(panel, struct o82_panel, panel);
	int ret, power_ret;

	if (!ctx->prepared && !ctx->enabled_supplies && !ctx->loaded_supplies)
		return 0;
	ret = ctx->prepared ? o82_off(ctx) : 0;
	power_ret = o82_power_off(ctx);
	ctx->prepared = false;
	return ret ? ret : power_ret;
}

static int o82_get_modes(struct drm_panel *panel, struct drm_connector *connector)
{
	struct o82_panel *ctx = container_of(panel, struct o82_panel, panel);
	int i, count = 0;

	ctx->connector = connector;
	for (i = 0; i < ARRAY_SIZE(o82_modes); i++) {
		struct drm_display_mode *mode;
		if (ctx->initial_60hz_only && drm_mode_vrefresh(&o82_modes[i].mode) != 60)
			continue;
		mode = drm_mode_duplicate(connector->dev, &o82_modes[i].mode);
		if (!mode)
			return -ENOMEM;
		drm_mode_set_name(mode);
		mode->type = DRM_MODE_TYPE_DRIVER;
		if (drm_mode_vrefresh(mode) == 60)
			mode->type |= DRM_MODE_TYPE_PREFERRED;
		drm_mode_probed_add(connector, mode);
		count++;
	}
	connector->display_info.bpc = 10;
	connector->display_info.width_mm = 237;
	connector->display_info.height_mm = 158;
	return count;
}

static const struct drm_panel_funcs o82_funcs = {
	.prepare = o82_prepare,
	.unprepare = o82_unprepare,
	.get_modes = o82_get_modes,
};

static int o82_probe(struct mipi_dsi_device *dsi)
{
	static const char * const supply_names[] = { "vddio", "vsp", "vsn" };
	static const int supply_voltages[] = { 1900000, 5800000, 5800000 };
	struct device *dev = &dsi->dev;
	struct device_node *node;
	struct mipi_dsi_host *host;
	struct o82_panel *ctx;
	const struct mipi_dsi_device_info info = { .type = "o82-secondary", .channel = 0 };
	int i, ret;

	ctx = devm_drm_panel_alloc(dev, struct o82_panel, panel, &o82_funcs,
				 DRM_MODE_CONNECTOR_DSI);
	if (IS_ERR(ctx))
		return PTR_ERR(ctx);
	ctx->dsi[0] = dsi;
	ctx->profiles = of_device_get_match_data(dev);
	if (!ctx->profiles)
		return -EINVAL;
	ctx->active = &ctx->profiles[0];
	/* shortcut: keep first native bring-up at 60 Hz until other modes are measured. */
	ctx->initial_60hz_only = of_property_read_bool(dev->of_node, "xiaomi,initial-60hz-only");
	for (i = 0; i < ARRAY_SIZE(supply_names); i++) {
		ctx->supplies[i] = devm_regulator_get(dev, supply_names[i]);
		if (IS_ERR(ctx->supplies[i]))
			return dev_err_probe(dev, PTR_ERR(ctx->supplies[i]), "Missing panel supply\n");
		ret = regulator_set_voltage(ctx->supplies[i], supply_voltages[i], supply_voltages[i]);
		if (ret)
			return dev_err_probe(dev, ret, "Cannot set stock panel voltage\n");
	}
	ctx->reset = devm_gpiod_get(dev, "reset", GPIOD_ASIS);
	if (IS_ERR(ctx->reset))
		return dev_err_probe(dev, PTR_ERR(ctx->reset), "Missing reset GPIO\n");
	node = of_graph_get_remote_node(dev->of_node, 1, -1);
	if (!node)
		return -ENODEV;
	host = of_find_mipi_dsi_host_by_node(node);
	of_node_put(node);
	if (!host)
		return -EPROBE_DEFER;
	ctx->dsi[1] = mipi_dsi_device_register_full(host, &info);
	if (IS_ERR(ctx->dsi[1]))
		return PTR_ERR(ctx->dsi[1]);
	ctx->dsc.dsc_version_major = 1;
	ctx->dsc.dsc_version_minor = 1;
	ctx->dsc.slice_width = 800;
	ctx->dsc.slice_height = 24;
	ctx->dsc.slice_count = 2;
	ctx->dsc.bits_per_component = 10;
	ctx->dsc.bits_per_pixel = 8 << 4;
	ctx->dsc.block_pred_enable = true;
	ret = drm_panel_of_backlight(&ctx->panel);
	if (ret)
		goto unregister_secondary;
	mipi_dsi_set_drvdata(dsi, ctx);
	ctx->panel.prepare_prev_first = true;
	drm_panel_add(&ctx->panel);
	for (i = 0; i < ARRAY_SIZE(ctx->dsi); i++) {
		ctx->dsi[i]->lanes = 4;
		/* OEM 30-bpp input retains RGB101010 on the DSC-capable wide bus. */
		ctx->dsi[i]->format = MIPI_DSI_FMT_RGB101010;
		ctx->dsi[i]->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_LPM;
		ctx->dsi[i]->dsc = &ctx->dsc;
		ret = mipi_dsi_attach(ctx->dsi[i]);
		if (ret)
			goto detach_attached;
	}
	return 0;

detach_attached:
	while (--i >= 0)
		mipi_dsi_detach(ctx->dsi[i]);
	drm_panel_remove(&ctx->panel);
unregister_secondary:
	mipi_dsi_device_unregister(ctx->dsi[1]);
	return ret;
}

static void o82_remove(struct mipi_dsi_device *dsi)
{
	struct o82_panel *ctx = mipi_dsi_get_drvdata(dsi);

	drm_panel_disable(&ctx->panel);
	if (o82_unprepare(&ctx->panel))
		dev_warn(&dsi->dev, "Panel power-down failed during removal\n");
	mipi_dsi_detach(ctx->dsi[1]);
	mipi_dsi_detach(ctx->dsi[0]);
	drm_panel_remove(&ctx->panel);
	mipi_dsi_device_unregister(ctx->dsi[1]);
}

static void o82_shutdown(struct mipi_dsi_device *dsi)
{
	struct o82_panel *ctx = mipi_dsi_get_drvdata(dsi);

	drm_panel_disable(&ctx->panel);
	if (o82_unprepare(&ctx->panel))
		dev_warn(&dsi->dev, "Panel power-down failed during shutdown\n");
}

static const struct of_device_id o82_match[] = {
	{ .compatible = "xiaomi,o82-36-02-0a", .data = o82_36_02_0a_profiles },
	{ .compatible = "xiaomi,o82-42-02-0b", .data = o82_42_02_0b_profiles },
	{ }
};
MODULE_DEVICE_TABLE(of, o82_match);

static struct mipi_dsi_driver o82_driver = {
	.probe = o82_probe,
	.remove = o82_remove,
	.shutdown = o82_shutdown,
	.driver = { .name = "panel-xiaomi-o82", .of_match_table = o82_match },
};
module_mipi_dsi_driver(o82_driver);
MODULE_DESCRIPTION("Xiaomi O82 dual-DSI panel with OEM timing groups");
MODULE_LICENSE("GPL");
