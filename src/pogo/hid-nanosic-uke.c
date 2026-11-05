// SPDX-License-Identifier: GPL-2.0-only
/*
 * POCO Pad X1 WN8030 transport. Protocol derived from map220v's GPL WN8030
 * driver (2025) and yzddmr6's bounded loader at 8ee5a1576e123ecbacfcfb9925d0f56820132bb8.
 * GPIOs, supplies, firmware identity, control prefix and pacing are Uke OEM
 * evidence. Accessory report compatibility still needs physical qualification.
 */
#include <crypto/sha2.h>
#include <linux/delay.h>
#include <linux/firmware.h>
#include <linux/gpio/consumer.h>
#include <linux/hex.h>
#include <linux/hid.h>
#include <linux/i2c.h>
#include <linux/input.h>
#include <linux/interrupt.h>
#include <linux/irq.h>
#include <linux/jiffies.h>
#include <linux/leds.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/pm_wakeup.h>
#include <linux/property.h>
#include <linux/random.h>
#include <linux/regulator/consumer.h>
#include <linux/slab.h>
#include <linux/workqueue.h>
#include "nanosic-uke-hid.h"
#include "nanosic-uke-protocol.h"

#define UKE_NANOSIC_FW "qcom/uke/nanosic/MCU_Upgrade.bin"
#define UKE_AUTH_TIMEOUT msecs_to_jiffies(5000)
#define UKE_KEEPALIVE msecs_to_jiffies(12000)

struct uke_nanosic {
	struct i2c_client *client;
	struct gpio_desc *reset, *wake;
	struct regulator_bulk_data supplies[2];
	struct mutex lock;
	struct hid_device *keyboard, *touchpad;
	struct input_dev *dock;
	struct led_classdev backlight, micmute;
	struct delayed_work rx_work, keepalive_work;
	struct work_struct policy_work, backlight_work;
	struct input_handler hall;
	bool vdd_on, dvdd_on, attached, suspended, removing, caps, lid_closed, folded;
	u8 requested_backlight, auth_phase;
	bool requested_micmute;
	bool input_allowed, auth_pending;
	bool backlight_registered;
	bool token_delivered;
	u32 auth_epoch;
	unsigned long auth_deadline;
	u8 uid[16], challenge[16], host_challenge[16];
	int data_irq;
	u64 frames, bad_frames, io_errors;
};

/* Caller holds lock, except during probe before callbacks exist. */
static int uke_nano_write(struct uke_nanosic *n, u8 reg, const u8 *data, size_t len)
{
	u8 buf[NANOSIC_FW_DATA_CMD_SIZE + 1];
	int ret;

	if (!len || len > NANOSIC_FW_DATA_CMD_SIZE)
		return -EINVAL;
	buf[0] = reg;
	memcpy(buf + 1, data, len);
	ret = i2c_master_send(n->client, buf, len + 1);
	memzero_explicit(buf, sizeof(buf));
	return ret == (int)len + 1 ? 0 : (ret < 0 ? ret : -EIO);
}

static int uke_nano_read(struct uke_nanosic *n, u8 reg, u8 *data, size_t len)
{
	struct i2c_msg msgs[] = {
		{ .addr = n->client->addr, .len = 1, .buf = &reg },
		{ .addr = n->client->addr, .flags = I2C_M_RD, .len = len, .buf = data },
	};
	int ret = i2c_transfer(n->client->adapter, msgs, ARRAY_SIZE(msgs));

	return ret == ARRAY_SIZE(msgs) ? 0 : (ret < 0 ? ret : -EIO);
}

static int uke_nano_cmd(struct uke_nanosic *n, u8 route, u8 opcode,
			const u8 *data, size_t len)
{
	u8 cmd[66];
	int ret;

	if (n->removing)
		return -ENODEV;
	if (n->suspended)
		return -EHOSTDOWN;
	ret = nanosic_uke_command(route, opcode, data, len, cmd);
	if (!ret)
		/* Uke runtime prefix is the client address, not boot register 0x5c. */
		ret = uke_nano_write(n, n->client->addr, cmd, sizeof(cmd));
	memzero_explicit(cmd, sizeof(cmd));
	if (ret)
		n->io_errors++;
	return ret;
}

static int uke_nano_control(struct uke_nanosic *n, u8 opcode, u8 value)
{
	return uke_nano_cmd(n, 0x4e, opcode, &value, 1);
}

static int uke_nano_boot_cmd(struct uke_nanosic *n, const u8 *data, size_t len)
{
	int ret = uke_nano_write(n, NANOSIC_BOOT_REGISTER, data, len);

	/* Exact Uke firmware-write wrapper waits 3 ms after each attempted write. */
	usleep_range(3000, 4000);
	return ret;
}

static int uke_nano_boot_value(struct uke_nanosic *n, u8 opcode)
{
	u8 value;
	int ret = uke_nano_boot_cmd(n, &opcode, 1);

	if (!ret)
		ret = uke_nano_read(n, NANOSIC_BOOT_REGISTER, &value, 1);
	return ret ? ret : value;
}

static int uke_nano_upload(struct uke_nanosic *n, const struct nanosic_firmware *fw)
{
	u8 cmd[NANOSIC_FW_DATA_CMD_SIZE];
	u32 offset = 0;
	int ret, count;

	ret = uke_nano_boot_value(n, 4);
	if (ret < 0)
		return ret;
	if (ret != 0xc8)
		return -ENODEV;
	ret = uke_nano_boot_value(n, 5);
	if (ret < 0)
		return ret;
	if (ret != 0)
		return -EPROTO;
	nanosic_firmware_header(fw, cmd);
	ret = uke_nano_boot_cmd(n, cmd, NANOSIC_FW_HEADER_CMD_SIZE);
	if (ret)
		return ret;
	ret = uke_nano_boot_value(n, 5);
	if (ret < 0)
		return ret;
	if (ret != 1)
		return -EPROTO;
	while (offset < fw->size) {
		count = nanosic_firmware_chunk(fw, offset, cmd);
		if (count < 0)
			return count;
		ret = uke_nano_boot_cmd(n, cmd, sizeof(cmd));
		if (ret)
			return ret;
		offset += count;
	}
	cmd[0] = 8;
	ret = uke_nano_boot_cmd(n, cmd, 1);
	if (ret)
		return ret;
	msleep(10);
	ret = uke_nano_boot_value(n, 5);
	if (ret < 0)
		return ret;
	if (ret != 3)
		return -EPROTO;
	cmd[0] = 9;
	ret = uke_nano_boot_cmd(n, cmd, 1);
	if (!ret)
		msleep(50);
	return ret;
}

static void uke_nano_release_inputs(struct uke_nanosic *n)
{
	u8 keys[9] = { 5 }, consumer[3] = { 6 }, tp[21] = { 0x19 };

	if (n->keyboard) {
		hid_input_report(n->keyboard, HID_INPUT_REPORT, keys, sizeof(keys), 1);
		hid_input_report(n->keyboard, HID_INPUT_REPORT, consumer, sizeof(consumer), 1);
	}
	if (n->touchpad)
		hid_input_report(n->touchpad, HID_INPUT_REPORT, tp, sizeof(tp), 1);
}

static void uke_nano_invalidate_auth(struct uke_nanosic *n)
{
	n->auth_pending = false;
	n->auth_phase = 0;
	n->auth_epoch++;
	memzero_explicit(n->uid, sizeof(n->uid));
	memzero_explicit(n->challenge, sizeof(n->challenge));
	memzero_explicit(n->host_challenge, sizeof(n->host_challenge));
}

static int uke_nano_restore(struct uke_nanosic *n)
{
	int ret;
	bool enable = n->attached && n->token_delivered &&
		!READ_ONCE(n->lid_closed) && !READ_ONCE(n->folded);

	if (n->input_allowed && !enable)
		uke_nano_release_inputs(n);
	n->input_allowed = enable;
	ret = uke_nano_control(n, 0x25, enable);
	if (!ret)
		ret = uke_nano_control(n, 0x21, enable);
	if (!ret)
		ret = uke_nano_control(n, 0x2e, enable && n->caps ? 0xfd : 0xfc);
	if (!ret)
		ret = uke_nano_control(n, 0x2e, enable && n->requested_micmute ? 0xf7 : 0xf3);
	if (!ret)
		ret = uke_nano_control(n, 0x23, enable ? n->requested_backlight : 0);
	return ret;
}

static void uke_nano_policy_work(struct work_struct *work)
{
	struct uke_nanosic *n = container_of(work, struct uke_nanosic, policy_work);

	mutex_lock(&n->lock);
	if (!n->suspended && !n->removing)
		uke_nano_restore(n);
	mutex_unlock(&n->lock);
}

static void uke_nano_keepalive(struct work_struct *work)
{
	struct uke_nanosic *n = container_of(to_delayed_work(work),
					    struct uke_nanosic, keepalive_work);

	mutex_lock(&n->lock);
	if (!n->suspended && !n->removing && n->attached) {
		uke_nano_control(n, 0x25, n->input_allowed);
		mod_delayed_work(system_wq, &n->keepalive_work, UKE_KEEPALIVE);
	}
	mutex_unlock(&n->lock);
}

/* Called with lock. No token wait or secure-world invocation in the IRQ. */
static void uke_nano_vendor(struct uke_nanosic *n, const u8 *p, size_t len)
{
	u8 payload[20] = { 0, 0, 0, 2 };

	if (len < 6)
		return;
	switch (p[4]) {
	case 0xa2:
		if (len < 10)
			break;
		if (n->attached != !!(p[9] & 1)) {
			uke_nano_release_inputs(n);
			uke_nano_invalidate_auth(n);
			n->attached = p[9] & 1;
			n->token_delivered = false;
			schedule_work(&n->backlight_work);
			input_report_switch(n->dock, SW_DOCK, n->attached);
			input_sync(n->dock);
			uke_nano_restore(n);
			if (n->attached)
				mod_delayed_work(system_wq, &n->keepalive_work, UKE_KEEPALIVE);
			/* A running worker rechecks attached before rearming. */
			else
				cancel_delayed_work(&n->keepalive_work);
		}
		break;
	case 0x24:
		if (n->attached) {
			uke_nano_release_inputs(n);
			n->input_allowed = false;
			n->token_delivered = false;
			uke_nano_invalidate_auth(n);
			if (!uke_nano_cmd(n, 0x4f, 0x31, (const u8 *)"MIAUTH", 6)) {
				n->auth_phase = 1;
				n->auth_deadline = jiffies + UKE_AUTH_TIMEOUT;
			}
		}
		break;
	case 0x31:
		if (!n->attached || len < 24 || n->auth_phase != 1 ||
		    time_after_eq(jiffies, n->auth_deadline))
			break;
		uke_nano_invalidate_auth(n);
		memcpy(n->uid, p + 8, 16);
		get_random_bytes(n->host_challenge, 16);
		memcpy(payload + 4, n->host_challenge, 16);
		if (!uke_nano_cmd(n, 0x4f, 0x32, payload, sizeof(payload))) {
			n->auth_phase = 2;
			n->auth_deadline = jiffies + UKE_AUTH_TIMEOUT;
		}
		break;
	case 0x32:
		if (!n->attached || len < 38 || n->auth_phase != 2 ||
		    time_after_eq(jiffies, n->auth_deadline))
			break;
		memcpy(n->challenge, p + 22, 16);
		n->auth_epoch++;
		n->auth_pending = true;
		n->auth_phase = 3;
		n->auth_deadline = jiffies + UKE_AUTH_TIMEOUT;
		sysfs_notify(&n->client->dev.kobj, NULL, "auth_request");
		break;
	}
	memzero_explicit(payload, sizeof(payload));
}

static int uke_nano_receive(struct uke_nanosic *n)
{
	u8 frame[NANOSIC_FRAME_SIZE];
	const u8 *p = frame + 3;
	int ret = uke_nano_read(n, NANOSIC_REPORT_REGISTER, frame, sizeof(frame));

	if (ret) {
		n->io_errors++;
		uke_nano_release_inputs(n);
		return ret;
	}
	ret = nanosic_uke_report(frame, sizeof(frame));
	if (ret < 0) {
		n->bad_frames++;
		uke_nano_release_inputs(n);
		goto out;
	}
	if (!ret)
		goto out;
	n->frames++;
	if (p[0] >= 0x22)
		uke_nano_vendor(n, p, ret);
	else if (n->input_allowed)
		hid_input_report(p[0] == 0x19 ? n->touchpad : n->keyboard,
				 HID_INPUT_REPORT, frame + 3, ret, 1);
out:
	memzero_explicit(frame, sizeof(frame));
	return ret;
}

static void uke_nano_drain(struct uke_nanosic *n)
{
	int i, ret;

	/* A noisy controller cannot keep the IRQ thread busy indefinitely. */
	for (i = 0; i < 8; i++) {
		ret = uke_nano_receive(n);
		if (ret <= 0)
			return;
	}
	mod_delayed_work(system_wq, &n->rx_work, msecs_to_jiffies(1));
}

static void uke_nano_rx_work(struct work_struct *work)
{
	struct uke_nanosic *n = container_of(to_delayed_work(work), struct uke_nanosic, rx_work);

	mutex_lock(&n->lock);
	if (!n->suspended && !n->removing)
		uke_nano_drain(n);
	mutex_unlock(&n->lock);
}

static irqreturn_t uke_nano_irq(int irq, void *data)
{
	struct uke_nanosic *n = data;

	mutex_lock(&n->lock);
	if (n->suspended)
		pm_wakeup_event(&n->client->dev, 1000);
	else if (!n->removing)
		uke_nano_drain(n);
	mutex_unlock(&n->lock);
	return IRQ_HANDLED;
}

static int uke_nano_hid_parse(struct hid_device *hid)
{
	return hid_parse_report(hid, (u8 *)(hid->product == 0xa1 ?
			hid_touchpad_descriptor : hid_keyboard_descriptor),
		hid->product == 0xa1 ? sizeof(hid_touchpad_descriptor) :
				      sizeof(hid_keyboard_descriptor));
}

static int uke_nano_hid_start(struct hid_device *hid) { return 0; }
static void uke_nano_hid_stop(struct hid_device *hid) {}
static int uke_nano_hid_open(struct hid_device *hid) { return 0; }
static void uke_nano_hid_close(struct hid_device *hid) {}

static int uke_nano_hid_output(struct hid_device *hid, u8 *buf, size_t count)
{
	struct uke_nanosic *n = hid->driver_data;
	int ret = 0;

	if (hid->product != 0xa3 || count != 2 || buf[0] != 5)
		return -EOPNOTSUPP;
	mutex_lock(&n->lock);
	if (n->removing)
		ret = -ENODEV;
	else {
		n->caps = buf[1] & 1;
		if (!n->suspended && n->input_allowed)
			ret = uke_nano_control(n, 0x2e, n->caps ? 0xfd : 0xfc);
	}
	mutex_unlock(&n->lock);
	return ret ? ret : count;
}

static int uke_nano_hid_raw(struct hid_device *hid, unsigned char id,
			    u8 *buf, size_t len, unsigned char type, int req)
{
	if (hid->product == 0xa1 && id == 0x19 && len >= 2 &&
	    type == HID_FEATURE_REPORT && req == HID_REQ_GET_REPORT) {
		buf[0] = 0x19;
		buf[1] = 3;
		return 2;
	}
	return -EOPNOTSUPP;
}

static const struct hid_ll_driver uke_nano_hid_ll = {
	.parse = uke_nano_hid_parse, .start = uke_nano_hid_start,
	.stop = uke_nano_hid_stop, .open = uke_nano_hid_open,
	.close = uke_nano_hid_close, .output_report = uke_nano_hid_output,
	.raw_request = uke_nano_hid_raw,
};

static int uke_nano_add_hid(struct uke_nanosic *n, bool touchpad)
{
	struct hid_device *hid = hid_allocate_device();
	int ret;

	if (IS_ERR(hid))
		return PTR_ERR(hid);
	hid->driver_data = n;
	hid->ll_driver = &uke_nano_hid_ll;
	hid->dev.parent = &n->client->dev;
	hid->bus = BUS_I2C;
	hid->vendor = 0x15d9;
	hid->product = touchpad ? 0xa1 : 0xa3;
	strscpy(hid->name, touchpad ? "Uke Pogo Touchpad" : "Uke Pogo Keyboard", sizeof(hid->name));
	snprintf(hid->phys, sizeof(hid->phys), "%s/%s", dev_name(&n->client->dev),
		 touchpad ? "touchpad" : "keyboard");
	ret = hid_add_device(hid);
	if (ret) {
		hid_destroy_device(hid);
		return ret;
	}
	if (touchpad)
		n->touchpad = hid;
	else
		n->keyboard = hid;
	return 0;
}

static int uke_nano_backlight(struct led_classdev *led, enum led_brightness value)
{
	struct uke_nanosic *n = container_of(led, struct uke_nanosic, backlight);
	int ret = 0;

	if (value > 100)
		return -EINVAL;
	mutex_lock(&n->lock);
	if (n->removing || !n->attached)
		/* LED teardown requests off; never lose the reconnect preference. */
		ret = value == LED_OFF ? 0 : -ENODEV;
	else {
		if (!n->suspended && n->input_allowed)
			ret = uke_nano_control(n, 0x23, value);
		if (!ret)
			n->requested_backlight = value;
	}
	mutex_unlock(&n->lock);
	return ret;
}

static enum led_brightness uke_nano_backlight_get(struct led_classdev *led)
{
	struct uke_nanosic *n = container_of(led, struct uke_nanosic, backlight);
	enum led_brightness value;

	mutex_lock(&n->lock);
	value = n->attached && !n->removing ? n->requested_backlight : LED_OFF;
	mutex_unlock(&n->lock);
	return value;
}

/* LED registration/removal may invoke brightness callbacks: never hold lock. */
static void uke_nano_backlight_work(struct work_struct *work)
{
	struct uke_nanosic *n = container_of(work, struct uke_nanosic, backlight_work);
	bool present;
	u8 value;
	int ret;

	mutex_lock(&n->lock);
	present = n->attached && !n->removing;
	value = n->requested_backlight;
	mutex_unlock(&n->lock);
	if (present && !n->backlight_registered) {
		/* A fresh class instance also clears LED-core state from a prior plug. */
		n->backlight = (struct led_classdev) {
			.name = "uke-pogo::kbd_backlight",
			.max_brightness = 100,
			.brightness = value,
			.brightness_set_blocking = uke_nano_backlight,
			.brightness_get = uke_nano_backlight_get,
		};
		ret = led_classdev_register(&n->client->dev, &n->backlight);
		if (ret) {
			dev_warn(&n->client->dev, "keyboard backlight registration failed: %d\n", ret);
			return;
		}
		WRITE_ONCE(n->backlight_registered, true);
	}
	/* Detach/remove may have raced registration; remove the stale endpoint. */
	mutex_lock(&n->lock);
	present = n->attached && !n->removing;
	mutex_unlock(&n->lock);
	if (!present && n->backlight_registered) {
		led_classdev_unregister(&n->backlight);
		WRITE_ONCE(n->backlight_registered, false);
	}
}

static int uke_nano_micmute(struct led_classdev *led, enum led_brightness value)
{
	struct uke_nanosic *n = container_of(led, struct uke_nanosic, micmute);
	int ret = 0;

	mutex_lock(&n->lock);
	if (n->removing)
		ret = -ENODEV;
	else {
		n->requested_micmute = !!value;
		if (!n->suspended && n->input_allowed)
			ret = uke_nano_control(n, 0x2e, value ? 0xf7 : 0xf3);
	}
	mutex_unlock(&n->lock);
	return ret;
}

/*
 * Root-only, versioned text handoff. No private UID/challenge enters a log.
 * Request: "1 EPOCH UID_HEX CHALLENGE_HEX HOST_CHALLENGE_HEX".
 * Reply: "EPOCH TOKEN_HEX". A reply belongs to exactly one live connection.
 * The trusted app/token provider remains a separate userspace dependency.
 */
static ssize_t auth_request_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct uke_nanosic *n = dev_get_drvdata(dev);
	ssize_t ret;

	mutex_lock(&n->lock);
	if (n->removing)
		ret = -ENODEV;
	else if (!n->auth_pending || time_after_eq(jiffies, n->auth_deadline))
		ret = -ENODATA;
	else
		ret = sysfs_emit(buf, "1 %u %*phN %*phN %*phN\n", n->auth_epoch,
				 16, n->uid, 16, n->challenge, 16, n->host_challenge);
	mutex_unlock(&n->lock);
	return ret;
}
static struct device_attribute dev_attr_auth_request = __ATTR(auth_request, 0400, auth_request_show, NULL);

static ssize_t auth_token_store(struct device *dev, struct device_attribute *attr,
				 const char *buf, size_t count)
{
	struct uke_nanosic *n = dev_get_drvdata(dev);
	char hex[33], tail;
	u8 token[16];
	unsigned int epoch;
	int ret;

	if (count > 45 || sscanf(buf, "%u %32s %c", &epoch, hex, &tail) != 2 ||
	    strlen(hex) != 32 || hex2bin(token, hex, 16))
		return -EINVAL;
	mutex_lock(&n->lock);
	if (n->removing)
		ret = -ENODEV;
	else if (!n->attached || !n->auth_pending || epoch != n->auth_epoch ||
		 time_after_eq(jiffies, n->auth_deadline))
		ret = -ESTALE;
	else {
		ret = uke_nano_cmd(n, 0x4f, 0x33, token, sizeof(token));
		/* Sending a token does not prove MCU authentication acceptance. */
		uke_nano_invalidate_auth(n);
		if (!ret) {
			n->token_delivered = true;
			ret = uke_nano_restore(n);
		}
	}
	mutex_unlock(&n->lock);
	memzero_explicit(token, sizeof(token));
	memzero_explicit(hex, sizeof(hex));
	return ret ? ret : count;
}
static struct device_attribute dev_attr_auth_token = __ATTR(auth_token, 0200, NULL, auth_token_store);

static ssize_t bridge_health_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct uke_nanosic *n = dev_get_drvdata(dev);
	ssize_t ret;

	mutex_lock(&n->lock);
	ret = sysfs_emit(buf, "attached=%u\nframes=%llu\nbad_frames=%llu\nio_errors=%llu\nauth_token_delivered=%u\n",
			 n->attached, n->frames, n->bad_frames, n->io_errors, n->token_delivered);
	mutex_unlock(&n->lock);
	return ret;
}
static DEVICE_ATTR_RO(bridge_health);
static struct attribute *uke_nano_attrs[] = {
	&dev_attr_auth_request.attr, &dev_attr_auth_token.attr, &dev_attr_bridge_health.attr, NULL,
};
ATTRIBUTE_GROUPS(uke_nano);

static void uke_nano_hall_event(struct input_handle *handle, unsigned int type,
				 unsigned int code, int value)
{
	struct uke_nanosic *n = handle->handler->private;

	if (type == EV_SW && code == SW_LID) {
		WRITE_ONCE(n->lid_closed, !!value);
		schedule_work(&n->policy_work);
	} else if (type == EV_SW && code == SW_TABLET_MODE) {
		WRITE_ONCE(n->folded, !!value);
		schedule_work(&n->policy_work);
	}
}

static int uke_nano_hall_connect(struct input_handler *handler, struct input_dev *dev,
				   const struct input_device_id *id)
{
	struct uke_nanosic *n = handler->private;
	struct input_handle *handle;
	int ret;

	if (!dev->name || (strcmp(dev->name, "Uke Hall Lid") &&
			  strcmp(dev->name, "Uke Hall Tablet Mode")))
		return -ENODEV;
	handle = kzalloc(sizeof(*handle), GFP_KERNEL);
	if (!handle)
		return -ENOMEM;
	handle->dev = dev;
	handle->handler = handler;
	handle->name = "uke-pogo-lid";
	ret = input_register_handle(handle);
	if (ret)
		goto free;
	ret = input_open_device(handle);
	if (ret) {
		input_unregister_handle(handle);
		goto free;
	}
	if (!strcmp(dev->name, "Uke Hall Lid"))
		WRITE_ONCE(n->lid_closed, test_bit(SW_LID, dev->sw));
	else
		WRITE_ONCE(n->folded, test_bit(SW_TABLET_MODE, dev->sw));
	schedule_work(&n->policy_work);
	return 0;
free:
	kfree(handle);
	return ret;
}

static void uke_nano_hall_disconnect(struct input_handle *handle)
{
	struct uke_nanosic *n = handle->handler->private;

	input_close_device(handle);
	input_unregister_handle(handle);
	if (!strcmp(handle->dev->name, "Uke Hall Lid"))
		WRITE_ONCE(n->lid_closed, false);
	else
		WRITE_ONCE(n->folded, false);
	schedule_work(&n->policy_work);
	kfree(handle);
}

static const struct input_device_id uke_nano_hall_ids[] = {
	{ .flags = INPUT_DEVICE_ID_MATCH_EVBIT | INPUT_DEVICE_ID_MATCH_SWBIT,
	  .evbit = { BIT_MASK(EV_SW) }, .swbit = { BIT_MASK(SW_LID) } },
	{ .flags = INPUT_DEVICE_ID_MATCH_EVBIT | INPUT_DEVICE_ID_MATCH_SWBIT,
	  .evbit = { BIT_MASK(EV_SW) }, .swbit = { BIT_MASK(SW_TABLET_MODE) } },
	{ }
};

static void uke_nano_power_off(struct uke_nanosic *n)
{
	int ret;

	gpiod_set_value_cansleep(n->wake, 0);
	gpiod_set_value_cansleep(n->reset, 1);
	/* Reverse the exact OEM sequence, and preserve votes on refused disable. */
	if (n->dvdd_on) {
		ret = regulator_disable(n->supplies[1].consumer);
		if (ret)
			dev_warn(&n->client->dev, "keyboard dvdd disable failed: %d\n", ret);
		else
			n->dvdd_on = false;
	}
	if (n->vdd_on && !n->dvdd_on) {
		ret = regulator_disable(n->supplies[0].consumer);
		if (ret)
			dev_warn(&n->client->dev, "keyboard vdd disable failed: %d\n", ret);
		else
			n->vdd_on = false;
	}
}

static int uke_nano_power_on(struct uke_nanosic *n)
{
	int ret;

	/* Uke Nanosic_switch_regulator: L22B 3.3 V first, L23B 1.8 V next. */
	ret = regulator_enable(n->supplies[0].consumer);
	if (ret)
		return ret;
	n->vdd_on = true;
	ret = regulator_enable(n->supplies[1].consumer);
	if (!ret)
		n->dvdd_on = true;
	/* Probe cleanup unwinds the first vote if the second enable failed. */
	return ret;
}

static void uke_nano_quiesce(struct uke_nanosic *n)
{
	mutex_lock(&n->lock);
	n->removing = true;
	n->input_allowed = false;
	uke_nano_invalidate_auth(n);
	mutex_unlock(&n->lock);
	cancel_work_sync(&n->policy_work);
	cancel_delayed_work_sync(&n->rx_work);
	cancel_delayed_work_sync(&n->keepalive_work);
	cancel_work_sync(&n->backlight_work);
	if (n->backlight_registered) {
		led_classdev_unregister(&n->backlight);
		n->backlight_registered = false;
	}
	/* No mutex held: HID/LED teardown may call our output callbacks. */
	if (n->touchpad)
		hid_destroy_device(n->touchpad);
	if (n->keyboard)
		hid_destroy_device(n->keyboard);
	uke_nano_power_off(n);
}

static int uke_nano_probe(struct i2c_client *client)
{
	static const u8 expected[SHA256_DIGEST_SIZE] = {
		0xb1, 0x7f, 0xa9, 0x38, 0xcf, 0x56, 0x13, 0xdf,
		0xa5, 0x50, 0x17, 0x9d, 0x6f, 0xc4, 0x0c, 0xfb,
		0xaa, 0x83, 0x1d, 0x53, 0x4a, 0x16, 0xa2, 0x22,
		0x82, 0xe2, 0x90, 0x4e, 0x84, 0x5f, 0xa7, 0xc4,
	};
	const struct i2c_adapter_quirks *quirks = client->adapter->quirks;
	const struct firmware *image;
	struct nanosic_firmware fw;
	struct device *dev = &client->dev;
	struct uke_nanosic *n;
	u8 digest[SHA256_DIGEST_SIZE];
	const char *name;
	int ret;

	if (client->addr != 0x4c || !i2c_check_functionality(client->adapter, I2C_FUNC_I2C))
		return -ENODEV;
	if (quirks && ((quirks->max_write_len && quirks->max_write_len < 513) ||
	    (quirks->max_read_len && quirks->max_read_len < 68) ||
	    (quirks->max_num_msgs && quirks->max_num_msgs < 2)))
		return -EOPNOTSUPP;
	ret = device_property_read_string(dev, "firmware-name", &name);
	if (ret || strcmp(name, UKE_NANOSIC_FW))
		return -EINVAL;
	/* Validate the exact retained RAM image before claiming GPIOs or powering it. */
	ret = request_firmware(&image, name, dev);
	if (ret)
		return dev_err_probe(dev, ret, "Uke keyboard MCU firmware unavailable\n");
	if (image->size != 82740) {
		ret = -EINVAL;
		goto release;
	}
	sha256(image->data, image->size, digest);
	if (memcmp(digest, expected, sizeof(digest))) {
		ret = -EBADMSG;
		goto release;
	}
	ret = nanosic_firmware_parse(image->data, image->size, &fw);
	if (ret)
		goto release;
	n = devm_kzalloc(dev, sizeof(*n), GFP_KERNEL);
	if (!n) {
		ret = -ENOMEM;
		goto release;
	}
	n->client = client;
	i2c_set_clientdata(client, n);
	mutex_init(&n->lock);
	INIT_DELAYED_WORK(&n->rx_work, uke_nano_rx_work);
	INIT_DELAYED_WORK(&n->keepalive_work, uke_nano_keepalive);
	INIT_WORK(&n->policy_work, uke_nano_policy_work);
	INIT_WORK(&n->backlight_work, uke_nano_backlight_work);
	n->reset = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(n->reset)) {
		ret = PTR_ERR(n->reset);
		goto release;
	}
	n->wake = devm_gpiod_get(dev, "wake", GPIOD_OUT_LOW);
	if (IS_ERR(n->wake)) {
		ret = PTR_ERR(n->wake);
		goto release;
	}
	/* Uke names: dvdd = L23B 1.8 V, vdd = L22B 3.3 V. No voltage retuning. */
	n->supplies[0].supply = "vdd";
	n->supplies[1].supply = "dvdd";
	ret = devm_regulator_bulk_get(dev, ARRAY_SIZE(n->supplies), n->supplies);
	if (ret)
		goto release;
	ret = uke_nano_power_on(n);
	if (ret)
		goto quiesce;
	usleep_range(2000, 3000);
	gpiod_set_value_cansleep(n->reset, 0);
	msleep(500);
	gpiod_set_value_cansleep(n->wake, 1);
	msleep(50);
	ret = uke_nano_upload(n, &fw);
	if (ret)
		goto quiesce;
	n->dock = devm_input_allocate_device(dev);
	if (!n->dock) {
		ret = -ENOMEM;
		goto quiesce;
	}
	n->dock->name = "Uke Pogo attachment";
	n->dock->id.bustype = BUS_I2C;
	input_set_capability(n->dock, EV_SW, SW_DOCK);
	ret = input_register_device(n->dock);
	if (ret)
		goto quiesce;
	ret = uke_nano_add_hid(n, false);
	if (ret)
		goto quiesce;
	ret = uke_nano_add_hid(n, true);
	if (ret)
		goto quiesce;
	n->micmute.name = "uke-pogo::micmute";
	n->micmute.max_brightness = 1;
	n->micmute.brightness_set_blocking = uke_nano_micmute;
	ret = led_classdev_register(dev, &n->micmute);
	if (ret)
		goto quiesce;
	n->hall.event = uke_nano_hall_event;
	n->hall.connect = uke_nano_hall_connect;
	n->hall.disconnect = uke_nano_hall_disconnect;
	n->hall.name = "uke-pogo-lid";
	n->hall.id_table = uke_nano_hall_ids;
	n->hall.private = n;
	ret = input_register_handler(&n->hall);
	if (ret)
		goto micmute;
	n->data_irq = fwnode_irq_get_byname(dev_fwnode(dev), "data");
	if (n->data_irq < 0) {
		ret = n->data_irq;
		goto hall;
	}
	ret = request_threaded_irq(n->data_irq, NULL, uke_nano_irq, IRQF_ONESHOT,
				   "uke-nanosic-data", n);
	if (ret)
		goto hall;
	mutex_lock(&n->lock);
	ret = uke_nano_control(n, 0xa1, 1);
	mutex_unlock(&n->lock);
	if (ret) {
		free_irq(n->data_irq, n);
		goto hall;
	}
	release_firmware(image);
	return 0;
hall:
	input_unregister_handler(&n->hall);
micmute:
	led_classdev_unregister(&n->micmute);
quiesce:
	uke_nano_quiesce(n);
release:
	release_firmware(image);
	return dev_err_probe(dev, ret, "WN8030 initialization failed\n");
}

static void uke_nano_remove(struct i2c_client *client)
{
	struct uke_nanosic *n = i2c_get_clientdata(client);

	mutex_lock(&n->lock);
	n->removing = true;
	n->input_allowed = false;
	uke_nano_release_inputs(n);
	uke_nano_invalidate_auth(n);
	mutex_unlock(&n->lock);
	free_irq(n->data_irq, n);
	input_unregister_handler(&n->hall);
	led_classdev_unregister(&n->micmute);
	uke_nano_quiesce(n);
}

static int uke_nano_suspend(struct device *dev)
{
	struct uke_nanosic *n = dev_get_drvdata(dev);

	mutex_lock(&n->lock);
	n->suspended = true;
	uke_nano_release_inputs(n);
	uke_nano_invalidate_auth(n);
	gpiod_set_value_cansleep(n->wake, 0);
	mutex_unlock(&n->lock);
	disable_irq(n->data_irq);
	cancel_work_sync(&n->policy_work);
	cancel_delayed_work_sync(&n->rx_work);
	cancel_delayed_work_sync(&n->keepalive_work);
	/* I2C core owns and arms the named dedicated wakeup IRQ from DT. */
	return 0;
}

static int uke_nano_resume(struct device *dev)
{
	struct uke_nanosic *n = dev_get_drvdata(dev);
	int ret;

	mutex_lock(&n->lock);
	gpiod_set_value_cansleep(n->wake, 1);
	msleep(50);
	n->suspended = false;
	ret = uke_nano_control(n, 0xa1, 1);
	if (!ret)
		ret = uke_nano_restore(n);
	if (n->attached)
		mod_delayed_work(system_wq, &n->keepalive_work, UKE_KEEPALIVE);
	mod_delayed_work(system_wq, &n->rx_work, 0);
	mutex_unlock(&n->lock);
	enable_irq(n->data_irq);
	return ret;
}

static DEFINE_SIMPLE_DEV_PM_OPS(uke_nano_pm, uke_nano_suspend, uke_nano_resume);
static const struct of_device_id uke_nano_match[] = {
	{ .compatible = "xiaomi,uke-wn8030" }, { }
};
MODULE_DEVICE_TABLE(of, uke_nano_match);
static struct i2c_driver uke_nano_driver = {
	.probe = uke_nano_probe, .remove = uke_nano_remove,
	.driver = {
		.name = "hid-nanosic-uke", .of_match_table = uke_nano_match,
		.pm = pm_sleep_ptr(&uke_nano_pm), .dev_groups = uke_nano_groups,
	},
};
module_i2c_driver(uke_nano_driver);
MODULE_FIRMWARE(UKE_NANOSIC_FW);
MODULE_DESCRIPTION("POCO Pad X1 Nanosic WN8030 pogo HID transport");
MODULE_LICENSE("GPL");
