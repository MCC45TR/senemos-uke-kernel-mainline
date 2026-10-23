// SPDX-License-Identifier: GPL-2.0-or-later
/* Uke THP packet transport. Contact processing remains in privileged userspace.
 * SPI framing follows the GPL-2-or-later Uke normal-RAM probe, not the
 * coordinate-firmware drivers for other NT36532 boards.
 */
#include <crypto/sha2.h>
#include <linux/delay.h>
#include <linux/firmware.h>
#include <linux/gpio/consumer.h>
#include <linux/interrupt.h>
#include <linux/irq.h>
#include <linux/module.h>
#include <linux/notifier.h>
#include <linux/of.h>
#include <linux/power_supply.h>
#include <linux/slab.h>
#include <linux/spi/spi.h>
#include <linux/uidgid.h>
#include <linux/uke-o82-touch.h>
#include <linux/workqueue.h>
#include <drm/drm_panel.h>
#include <media/v4l2-device.h>
#include <media/v4l2-fh.h>
#include <media/v4l2-ioctl.h>
#include <media/videobuf2-v4l2.h>
#include <media/videobuf2-vmalloc.h>

#include "nt36532-uke-protocol.h"

#define NVT_UKE_FIRMWARE "novatek/uke/nt36532-normal.bin"
#define NVT_UKE_WIRE_SIZE (NVT_UKE_FRAME_SIZE + 2)

struct nvt_uke_buffer {
	struct vb2_v4l2_buffer vb;
	struct list_head list;
};

struct nvt_uke_touch {
	struct spi_device *spi;
	struct v4l2_device v4l2;
	struct video_device video;
	struct vb2_queue queue;
	struct drm_panel_follower follower;
	struct notifier_block panel_notifier;
	struct notifier_block supply_notifier;
	const struct firmware *firmware;
	struct nvt_uke_io io;
	struct work_struct boot_work;
	struct work_struct charger_work;
	/* ctrl changes state; workers never acquire it or a panel lock. */
	struct mutex ctrl, io_lock, irq_lock, queue_lock;
	spinlock_t state_lock, buffers_lock;
	struct list_head buffers;
	u64 epoch, transfer_epoch, panel_state;
	bool streaming, panel_ready, suspended, removed, fault;
	bool irq_enabled, booted, idle_reset;
	bool charger_known, charger_online;
	u32 sequence;
	unsigned int watchdog;
	u8 *tx, *rx, *frame;
};

static bool nvt_active(struct nvt_uke_touch *t)
{
	return t->streaming && t->panel_ready && !t->suspended &&
		!t->removed && !t->fault;
}

static int nvt_ready(void *context)
{
	struct nvt_uke_touch *t = context;
	unsigned long flags;
	int ret;

	spin_lock_irqsave(&t->state_lock, flags);
	ret = nvt_active(t) && t->transfer_epoch == t->epoch ? 0 : -ESHUTDOWN;
	spin_unlock_irqrestore(&t->state_lock, flags);
	return ret;
}

/* io_lock owns the page, buffers and transfer_epoch for the entire operation. */
static int nvt_transfer(struct nvt_uke_touch *t, size_t size, bool receive, bool fast)
{
	struct spi_transfer xfer = {
		.tx_buf = t->tx, .rx_buf = receive ? t->rx : NULL,
		.len = size, .speed_hz = fast ? 19200000 : 1000000,
		.bits_per_word = 8,
	};
	struct spi_message message;
	int ret = nvt_ready(t);

	if (ret)
		return ret;
	spi_message_init_with_transfers(&message, &xfer, 1);
	ret = spi_sync(t->spi, &message);
	if (ret)
		return ret;
	if (message.actual_length != size)
		return -EIO;
	return nvt_ready(t);
}

static int nvt_spi_io(struct nvt_uke_touch *t, u32 address, void *data,
		      size_t size, bool read, bool fast)
{
	int ret;

	if (!data || !size || size > NVT_UKE_FRAME_SIZE ||
	    address > 0xffffff || size - 1 > 0xffffff - address)
		return -EINVAL;
	t->tx[0] = 0xff;
	t->tx[1] = address >> 15;
	t->tx[2] = address >> 7;
	ret = nvt_transfer(t, 3, false, false);
	if (ret)
		return ret;
	memset(t->tx, 0, size + 2);
	t->tx[0] = (address & 0x7f) | (read ? 0 : 0x80);
	if (!read)
		memcpy(t->tx + 1, data, size);
	ret = nvt_transfer(t, size + (read ? 2 : 1), read, fast);
	if (!ret && read)
		memcpy(data, t->rx + 2, size);
	return ret;
}

static int nvt_read(void *context, u32 address, void *data, size_t size, bool fast)
{
	return nvt_spi_io(context, address, data, size, true, fast);
}

static int nvt_write(void *context, u32 address, const void *data, size_t size, bool fast)
{
	return nvt_spi_io(context, address, (void *)data, size, false, fast);
}

static void nvt_delay(void *context, unsigned int milliseconds)
{
	msleep(milliseconds);
}

static int nvt_sha256(void *context, const u8 *data, size_t size, u8 digest[32])
{
	sha256(data, size, digest);
	return 0;
}

static void nvt_irq_set(struct nvt_uke_touch *t, bool enabled)
{
	unsigned long flags;
	bool active;

	mutex_lock(&t->irq_lock);
	spin_lock_irqsave(&t->state_lock, flags);
	active = nvt_active(t) && t->transfer_epoch == t->epoch;
	spin_unlock_irqrestore(&t->state_lock, flags);
	enabled &= active;
	if (enabled != t->irq_enabled) {
		if (enabled)
			enable_irq(t->spi->irq);
		else
			disable_irq(t->spi->irq);
		t->irq_enabled = enabled;
	}
	mutex_unlock(&t->irq_lock);
}

static void nvt_quiesce(struct nvt_uke_touch *t)
{
	/* State was invalidated first. Drain IRQ before its last work enqueue. */
	nvt_irq_set(t, false);
	cancel_work_sync(&t->boot_work);
	cancel_work_sync(&t->charger_work);
	mutex_lock(&t->io_lock);
	t->booted = false;
	t->watchdog = 0;
	t->idle_reset = false;
	mutex_unlock(&t->io_lock);
}

static void nvt_fault(struct nvt_uke_touch *t)
{
	unsigned long flags;

	spin_lock_irqsave(&t->state_lock, flags);
	t->fault = true;
	t->epoch++;
	spin_unlock_irqrestore(&t->state_lock, flags);
	vb2_queue_error(&t->queue);
}

static void nvt_apply_charger(struct nvt_uke_touch *t)
{
	struct power_supply *supply;
	union power_supply_propval value;
	int ret;

	if (!t->booted || nvt_ready(t))
		return;
	supply = power_supply_get_by_name("qcom-battmgr-usb");
	if (!supply)
		return;
	ret = power_supply_get_property(supply, POWER_SUPPLY_PROP_ONLINE, &value);
	power_supply_put(supply);
	if (ret || (value.intval != 0 && value.intval != 1))
		return;
	if (t->charger_known && t->charger_online == value.intval)
		return;
	ret = nvt_uke_charger(&t->io, value.intval);
	if (!ret) {
		t->charger_online = value.intval;
		t->charger_known = true;
	} else if (ret != -ESHUTDOWN) {
		dev_warn_ratelimited(&t->spi->dev, "THP charger filter unavailable: %d\n", ret);
	}
}

static void nvt_charger_worker(struct work_struct *work)
{
	struct nvt_uke_touch *t = container_of(work, struct nvt_uke_touch, charger_work);

	mutex_lock(&t->io_lock);
	nvt_apply_charger(t);
	mutex_unlock(&t->io_lock);
}

static int nvt_supply_changed(struct notifier_block *nb, unsigned long event, void *data)
{
	struct nvt_uke_touch *t = container_of(nb, struct nvt_uke_touch, supply_notifier);
	struct power_supply *supply = data;

	if (event == PSY_EVENT_PROP_CHANGED &&
	    !strcmp(supply->desc->name, "qcom-battmgr-usb"))
		queue_work(system_long_wq, &t->charger_work);
	return NOTIFY_OK;
}

static void nvt_boot_worker(struct work_struct *work)
{
	struct nvt_uke_touch *t = container_of(work, struct nvt_uke_touch, boot_work);
	unsigned long flags;
	int ret;

	nvt_irq_set(t, false);
	mutex_lock(&t->io_lock);
	spin_lock_irqsave(&t->state_lock, flags);
	t->transfer_epoch = t->epoch;
	spin_unlock_irqrestore(&t->state_lock, flags);
	t->booted = false;
	ret = nvt_ready(t);
	if (!ret)
		ret = nvt_uke_boot(&t->io, t->firmware->data, t->firmware->size,
				   t->idle_reset);
	t->idle_reset = false;
	t->watchdog = 0;
	if (!ret) {
		t->booted = true;
		t->charger_known = false;
		nvt_apply_charger(t);
	} else if (ret != -ESHUTDOWN) {
		nvt_fault(t);
		dev_err_ratelimited(&t->spi->dev, "THP firmware start failed: %d\n", ret);
	}
	mutex_unlock(&t->io_lock);
	if (!ret)
		nvt_irq_set(t, true);
}

static void nvt_complete(struct nvt_uke_touch *t, bool valid)
{
	struct nvt_uke_buffer *buffer = NULL;
	unsigned long flags;

	spin_lock_irqsave(&t->buffers_lock, flags);
	if (!list_empty(&t->buffers)) {
		buffer = list_first_entry(&t->buffers, struct nvt_uke_buffer, list);
		list_del(&buffer->list);
	}
	spin_unlock_irqrestore(&t->buffers_lock, flags);
	if (!buffer)
		return;
	if (valid)
		memcpy(vb2_plane_vaddr(&buffer->vb.vb2_buf, 0), t->frame, NVT_UKE_FRAME_SIZE);
	vb2_set_plane_payload(&buffer->vb.vb2_buf, 0, valid ? NVT_UKE_FRAME_SIZE : 0);
	buffer->vb.vb2_buf.timestamp = ktime_get_ns();
	buffer->vb.sequence = t->sequence++;
	buffer->vb.field = V4L2_FIELD_NONE;
	vb2_buffer_done(&buffer->vb.vb2_buf, valid ? VB2_BUF_STATE_DONE : VB2_BUF_STATE_ERROR);
}

static irqreturn_t nvt_irq_thread(int irq, void *context)
{
	struct nvt_uke_touch *t = context;
	struct nvt_uke_frame decoded;
	int ret, watchdog;

	mutex_lock(&t->io_lock);
	if (!t->booted || nvt_ready(t))
		goto out;
	ret = nvt_uke_read_frame(&t->io, t->frame);
	if (ret) {
		if (ret != -ESHUTDOWN) {
			t->booted = false;
			nvt_fault(t);
			/* The worker disables IRQ outside this threaded handler. */
			queue_work(system_long_wq, &t->boot_work);
		}
		goto out;
	}
	watchdog = nvt_uke_watchdog(t->frame, NVT_UKE_FRAME_SIZE, &t->watchdog);
	ret = nvt_uke_decode(t->frame, NVT_UKE_FRAME_SIZE, &decoded);
	if (nvt_ready(t))
		goto out;
	nvt_complete(t, !ret);
	if (watchdog > 0) {
		t->idle_reset = watchdog == 0xfd;
		t->booted = false;
		queue_work(system_long_wq, &t->boot_work);
	}
out:
	mutex_unlock(&t->io_lock);
	return IRQ_HANDLED;
}

static int nvt_panel_changed(struct notifier_block *nb, unsigned long event, void *data)
{
	struct nvt_uke_touch *t = container_of(nb, struct nvt_uke_touch, panel_notifier);
	u64 state = *(u64 *)data;
	unsigned long flags;
	bool active;

	mutex_lock(&t->ctrl);
	if (state != t->panel_state) {
		spin_lock_irqsave(&t->state_lock, flags);
		t->panel_state = state;
		t->panel_ready = false;
		t->epoch++;
		spin_unlock_irqrestore(&t->state_lock, flags);
		nvt_quiesce(t);
		spin_lock_irqsave(&t->state_lock, flags);
		t->panel_ready = state & 1;
		active = nvt_active(t);
		spin_unlock_irqrestore(&t->state_lock, flags);
		if (active)
			queue_work(system_long_wq, &t->boot_work);
	}
	mutex_unlock(&t->ctrl);
	return NOTIFY_OK;
}

static int nvt_queue_setup(struct vb2_queue *q, unsigned int *count,
			   unsigned int *planes, unsigned int sizes[], struct device *devices[])
{
	if (*planes)
		return *planes == 1 && sizes[0] >= NVT_UKE_FRAME_SIZE ? 0 : -EINVAL;
	*planes = 1;
	sizes[0] = NVT_UKE_FRAME_SIZE;
	return 0;
}

static int nvt_buffer_prepare(struct vb2_buffer *vb)
{
	if (vb2_plane_size(vb, 0) < NVT_UKE_FRAME_SIZE)
		return -EINVAL;
	vb2_set_plane_payload(vb, 0, 0);
	return 0;
}

static void nvt_buffer_queue(struct vb2_buffer *vb)
{
	struct nvt_uke_touch *t = vb2_get_drv_priv(vb->vb2_queue);
	struct nvt_uke_buffer *buffer = container_of(to_vb2_v4l2_buffer(vb),
						    struct nvt_uke_buffer, vb);
	unsigned long flags;

	spin_lock_irqsave(&t->buffers_lock, flags);
	list_add_tail(&buffer->list, &t->buffers);
	spin_unlock_irqrestore(&t->buffers_lock, flags);
}

static int nvt_start_streaming(struct vb2_queue *q, unsigned int count)
{
	struct nvt_uke_touch *t = vb2_get_drv_priv(q);
	unsigned long flags;
	bool active;

	mutex_lock(&t->ctrl);
	spin_lock_irqsave(&t->state_lock, flags);
	t->streaming = true;
	t->fault = false;
	t->epoch++;
	active = nvt_active(t);
	spin_unlock_irqrestore(&t->state_lock, flags);
	t->sequence = 0;
	if (active)
		queue_work(system_long_wq, &t->boot_work);
	mutex_unlock(&t->ctrl);
	return 0;
}

static void nvt_stop_streaming(struct vb2_queue *q)
{
	struct nvt_uke_touch *t = vb2_get_drv_priv(q);
	struct nvt_uke_buffer *buffer, *next;
	unsigned long flags;
	LIST_HEAD(pending);

	mutex_lock(&t->ctrl);
	spin_lock_irqsave(&t->state_lock, flags);
	t->streaming = false;
	t->epoch++;
	spin_unlock_irqrestore(&t->state_lock, flags);
	nvt_quiesce(t);
	spin_lock_irqsave(&t->buffers_lock, flags);
	list_splice_init(&t->buffers, &pending);
	spin_unlock_irqrestore(&t->buffers_lock, flags);
	list_for_each_entry_safe(buffer, next, &pending, list) {
		list_del(&buffer->list);
		vb2_set_plane_payload(&buffer->vb.vb2_buf, 0, 0);
		vb2_buffer_done(&buffer->vb.vb2_buf, VB2_BUF_STATE_ERROR);
	}
	mutex_unlock(&t->ctrl);
}

static const struct vb2_ops nvt_queue_ops = {
	.queue_setup = nvt_queue_setup,
	.buf_prepare = nvt_buffer_prepare,
	.buf_queue = nvt_buffer_queue,
	.start_streaming = nvt_start_streaming,
	.stop_streaming = nvt_stop_streaming,
};

static int nvt_querycap(struct file *file, void *priv, struct v4l2_capability *cap)
{
	strscpy(cap->driver, "nt36532-uke-thp", sizeof(cap->driver));
	strscpy(cap->card, "Uke NT36532 raw THP", sizeof(cap->card));
	strscpy(cap->bus_info, "platform:uke-thp", sizeof(cap->bus_info));
	return 0;
}

static int nvt_enum_format(struct file *file, void *priv, struct v4l2_fmtdesc *fmt)
{
	if (fmt->index)
		return -EINVAL;
	fmt->pixelformat = V4L2_META_FMT_GENERIC_8;
	fmt->flags = V4L2_FMT_FLAG_META_LINE_BASED;
	strscpy(fmt->description, "NT36532 Uke THP packet", sizeof(fmt->description));
	return 0;
}

static int nvt_format(struct file *file, void *priv, struct v4l2_format *fmt)
{
	memset(&fmt->fmt.meta, 0, sizeof(fmt->fmt.meta));
	fmt->fmt.meta.dataformat = V4L2_META_FMT_GENERIC_8;
	fmt->fmt.meta.buffersize = NVT_UKE_FRAME_SIZE;
	fmt->fmt.meta.width = NVT_UKE_FRAME_SIZE;
	fmt->fmt.meta.height = 1;
	fmt->fmt.meta.bytesperline = NVT_UKE_FRAME_SIZE;
	return 0;
}

static const struct v4l2_ioctl_ops nvt_ioctl_ops = {
	.vidioc_querycap = nvt_querycap,
	.vidioc_enum_fmt_meta_cap = nvt_enum_format,
	.vidioc_g_fmt_meta_cap = nvt_format,
	.vidioc_s_fmt_meta_cap = nvt_format,
	.vidioc_try_fmt_meta_cap = nvt_format,
	.vidioc_reqbufs = vb2_ioctl_reqbufs,
	.vidioc_create_bufs = vb2_ioctl_create_bufs,
	.vidioc_prepare_buf = vb2_ioctl_prepare_buf,
	.vidioc_querybuf = vb2_ioctl_querybuf,
	.vidioc_qbuf = vb2_ioctl_qbuf,
	.vidioc_dqbuf = vb2_ioctl_dqbuf,
	.vidioc_streamon = vb2_ioctl_streamon,
	.vidioc_streamoff = vb2_ioctl_streamoff,
};

static int nvt_open(struct file *file)
{
	/* Raw matrices expose input; video-group membership is insufficient. */
	if (!uid_eq(current_euid(), GLOBAL_ROOT_UID))
		return -EACCES;
	return v4l2_fh_open(file);
}

static const struct v4l2_file_operations nvt_fops = {
	.owner = THIS_MODULE,
	.open = nvt_open,
	.release = vb2_fop_release,
	.read = vb2_fop_read,
	.poll = vb2_fop_poll,
	.mmap = vb2_fop_mmap,
	.unlocked_ioctl = video_ioctl2,
};

static void nvt_release(struct v4l2_device *v4l2)
{
	struct nvt_uke_touch *t = container_of(v4l2, struct nvt_uke_touch, v4l2);

	v4l2_device_unregister(v4l2);
	release_firmware(t->firmware);
	kfree(t->frame);
	kfree(t->rx);
	kfree(t->tx);
	kfree(t);
}

static const struct drm_panel_follower_funcs nvt_follower_funcs = { };

static int nvt_probe(struct spi_device *spi)
{
	struct device *dev = &spi->dev;
	struct gpio_desc *panel_id;
	struct nvt_uke_touch *t;
	int ret;

	if (!of_machine_is_compatible("xiaomi,uke") || spi->max_speed_hz != 19200000 ||
	    spi->mode != SPI_MODE_0 || spi->irq <= 0 ||
	    irq_get_trigger_type(spi->irq) != IRQ_TYPE_EDGE_RISING)
		return -ENODEV;
	if (spi_max_transfer_size(spi) < NVT_UKE_WIRE_SIZE ||
	    spi_max_message_size(spi) < NVT_UKE_WIRE_SIZE)
		return dev_err_probe(dev, -EMSGSIZE, "Complete THP packet transfer required\n");
	panel_id = devm_gpiod_get(dev, "panel-id", GPIOD_ASIS);
	if (IS_ERR(panel_id))
		return dev_err_probe(dev, PTR_ERR(panel_id), "Panel ID unavailable\n");
	if (gpiod_get_direction(panel_id) != 1 || gpiod_get_value_cansleep(panel_id) != 1)
		return dev_err_probe(dev, -ENODEV, "Expected existing high panel-ID input\n");
	t = kzalloc_obj(*t);
	if (!t)
		return -ENOMEM;
	t->spi = spi;
	mutex_init(&t->ctrl);
	mutex_init(&t->io_lock);
	mutex_init(&t->irq_lock);
	mutex_init(&t->queue_lock);
	spin_lock_init(&t->state_lock);
	spin_lock_init(&t->buffers_lock);
	INIT_LIST_HEAD(&t->buffers);
	INIT_WORK(&t->boot_work, nvt_boot_worker);
	INIT_WORK(&t->charger_work, nvt_charger_worker);
	t->io = (struct nvt_uke_io) {
		.context = t, .read = nvt_read, .write = nvt_write,
		.check_ready = nvt_ready, .delay_ms = nvt_delay, .sha256 = nvt_sha256,
	};
	t->v4l2.release = nvt_release;
	spi_set_drvdata(spi, t);
	ret = v4l2_device_register(dev, &t->v4l2);
	if (ret) {
		spi_set_drvdata(spi, NULL);
		kfree(t);
		return ret;
	}
	t->tx = kmalloc(NVT_UKE_WIRE_SIZE, GFP_KERNEL);
	t->rx = kmalloc(NVT_UKE_WIRE_SIZE, GFP_KERNEL);
	t->frame = kmalloc(NVT_UKE_FRAME_SIZE, GFP_KERNEL);
	ret = -ENOMEM;
	if (!t->tx || !t->rx || !t->frame)
		goto put;
	ret = request_firmware(&t->firmware, NVT_UKE_FIRMWARE, dev);
	if (ret)
		goto put;
	ret = nvt_uke_validate_image(&t->io, t->firmware->data, t->firmware->size);
	if (ret)
		goto put;
	spi->bits_per_word = 8;
	ret = spi_setup(spi);
	if (ret)
		goto put;
	ret = devm_request_threaded_irq(dev, spi->irq, NULL, nvt_irq_thread,
			IRQF_ONESHOT | IRQF_NO_AUTOEN, dev_name(dev), t);
	if (ret)
		goto put;
	t->follower.funcs = &nvt_follower_funcs;
	ret = drm_panel_add_follower(dev, &t->follower);
	if (ret)
		goto free_irq;
	if (!device_link_add(dev, t->follower.panel->dev, DL_FLAG_AUTOREMOVE_CONSUMER)) {
		ret = -ENODEV;
		goto follower;
	}
	t->queue = (struct vb2_queue) {
		.type = V4L2_BUF_TYPE_META_CAPTURE,
		.io_modes = VB2_MMAP | VB2_READ,
		.drv_priv = t, .buf_struct_size = sizeof(struct nvt_uke_buffer),
		.ops = &nvt_queue_ops, .mem_ops = &vb2_vmalloc_memops,
		.timestamp_flags = V4L2_BUF_FLAG_TIMESTAMP_MONOTONIC,
		.lock = &t->queue_lock, .dev = dev,
		.min_queued_buffers = 1,
	};
	ret = vb2_queue_init(&t->queue);
	if (ret)
		goto follower;
	t->supply_notifier.notifier_call = nvt_supply_changed;
	ret = power_supply_reg_notifier(&t->supply_notifier);
	if (ret)
		goto queue;
	t->panel_notifier.notifier_call = nvt_panel_changed;
	ret = uke_o82_touch_register(t->follower.panel, &t->panel_notifier);
	if (ret)
		goto supply;
	strscpy(t->video.name, "Uke NT36532 THP", sizeof(t->video.name));
	t->video.v4l2_dev = &t->v4l2;
	t->video.fops = &nvt_fops;
	t->video.ioctl_ops = &nvt_ioctl_ops;
	t->video.release = video_device_release_empty;
	t->video.lock = &t->queue_lock;
	t->video.queue = &t->queue;
	t->video.device_caps = V4L2_CAP_META_CAPTURE | V4L2_CAP_STREAMING | V4L2_CAP_READWRITE;
	video_set_drvdata(&t->video, t);
	ret = video_register_device(&t->video, VFL_TYPE_VIDEO, -1);
	if (!ret)
		return 0;
	uke_o82_touch_unregister(t->follower.panel, &t->panel_notifier);
supply:
	power_supply_unreg_notifier(&t->supply_notifier);
	nvt_quiesce(t);
queue:
	vb2_queue_release(&t->queue);
follower:
	drm_panel_remove_follower(&t->follower);
free_irq:
	devm_free_irq(dev, spi->irq, t);
put:
	spi_set_drvdata(spi, NULL);
	v4l2_device_put(&t->v4l2);
	return dev_err_probe(dev, ret, "THP capture registration failed\n");
}

static void nvt_remove(struct spi_device *spi)
{
	struct nvt_uke_touch *t = spi_get_drvdata(spi);
	unsigned long flags;

	mutex_lock(&t->ctrl);
	spin_lock_irqsave(&t->state_lock, flags);
	t->removed = true;
	t->epoch++;
	spin_unlock_irqrestore(&t->state_lock, flags);
	mutex_unlock(&t->ctrl);
	uke_o82_touch_unregister(t->follower.panel, &t->panel_notifier);
	power_supply_unreg_notifier(&t->supply_notifier);
	nvt_quiesce(t);
	devm_free_irq(&spi->dev, spi->irq, t);
	drm_panel_remove_follower(&t->follower);
	v4l2_device_disconnect(&t->v4l2);
	vb2_video_unregister_device(&t->video);
	spi_set_drvdata(spi, NULL);
	/* Existing file descriptors retain the V4L2 reference until their release. */
	v4l2_device_put(&t->v4l2);
}

static int nvt_suspend(struct device *dev)
{
	struct nvt_uke_touch *t = dev_get_drvdata(dev);
	unsigned long flags;

	mutex_lock(&t->ctrl);
	spin_lock_irqsave(&t->state_lock, flags);
	t->suspended = true;
	t->epoch++;
	spin_unlock_irqrestore(&t->state_lock, flags);
	nvt_quiesce(t);
	vb2_discard_done(&t->queue);
	mutex_unlock(&t->ctrl);
	return 0;
}

static int nvt_resume(struct device *dev)
{
	struct nvt_uke_touch *t = dev_get_drvdata(dev);
	unsigned long flags;
	bool active;

	mutex_lock(&t->ctrl);
	spin_lock_irqsave(&t->state_lock, flags);
	t->suspended = false;
	t->epoch++;
	active = nvt_active(t);
	spin_unlock_irqrestore(&t->state_lock, flags);
	if (active)
		queue_work(system_long_wq, &t->boot_work);
	mutex_unlock(&t->ctrl);
	return 0;
}

static DEFINE_SIMPLE_DEV_PM_OPS(nvt_pm_ops, nvt_suspend, nvt_resume);

static void nvt_shutdown(struct spi_device *spi)
{
	nvt_suspend(&spi->dev);
}

static const struct of_device_id nvt_matches[] = {
	{ .compatible = "novatek,nt36532-uke-thp" }, { }
};
MODULE_DEVICE_TABLE(of, nvt_matches);

static const struct spi_device_id nvt_spi_ids[] = {
	{ "nt36532-uke-thp" }, { }
};
MODULE_DEVICE_TABLE(spi, nvt_spi_ids);

static struct spi_driver nvt_driver = {
	.driver = {
		.name = "nt36532-uke-thp",
		.of_match_table = nvt_matches,
		.pm = pm_sleep_ptr(&nvt_pm_ops),
	},
	.probe = nvt_probe,
	.remove = nvt_remove,
	.shutdown = nvt_shutdown,
	.id_table = nvt_spi_ids,
};
module_spi_driver(nvt_driver);
MODULE_FIRMWARE(NVT_UKE_FIRMWARE);
MODULE_DESCRIPTION("Uke NT36532 signed raw THP packet transport");
MODULE_LICENSE("GPL");
