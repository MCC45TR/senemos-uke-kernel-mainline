// SPDX-License-Identifier: GPL-2.0-only
// Exact Uke FourSemi ABI. Never log or expose per-unit parameter contents.
#include <crypto/hash.h>
#include <linux/capability.h>
#include <linux/cleanup.h>
#include <linux/hex.h>
#include <linux/mutex.h>
#include <linux/of.h>
#include <linux/workqueue.h>
#include <sound/control.h>
#include <sound/soc.h>
#include <sound/uke-fs19xx-guard.h>
#include "audioreach.h"
#include "q6apm.h"
#include "uke-fs19xx-protocol.h"
#include "uke-fs19xx-runtime.h"

struct q6apm_fs19xx {
	struct mutex lock;
	struct uke_fs19xx_state data;
	struct audioreach_graph *owner;
	struct crypto_shash *sha256;
	bool removing;
};

/* No pointer into a removable APM device is exposed to an amplifier. */
static DEFINE_MUTEX(fs19xx_listeners_lock);
static BLOCKING_NOTIFIER_HEAD(fs19xx_listeners);
static unsigned int fs19xx_positions;
static atomic_t fs19xx_mode = ATOMIC_INIT(0);
static atomic_t fs19xx_faulted = ATOMIC_INIT(0);

bool q6apm_fs19xx_configured(void)
{ return !atomic_read(&fs19xx_faulted) && atomic_read(&fs19xx_mode) >= 1; }
EXPORT_SYMBOL_GPL(q6apm_fs19xx_configured);
bool q6apm_fs19xx_running(void)
{ return !atomic_read(&fs19xx_faulted) && atomic_read(&fs19xx_mode) == 2; }
EXPORT_SYMBOL_GPL(q6apm_fs19xx_running);

static int fs19xx_gate(unsigned int mode)
{
	int ret = 0;

	guard(mutex)(&fs19xx_listeners_lock);
	if (mode && (fs19xx_positions != 15 || atomic_read(&fs19xx_faulted)))
		return -ENODEV;
	atomic_set(&fs19xx_mode, mode);
	if (mode != 1)
		ret = notifier_to_errno(blocking_notifier_call_chain(&fs19xx_listeners, mode, NULL));
	if (ret) {
		atomic_set(&fs19xx_mode, 0);
		blocking_notifier_call_chain(&fs19xx_listeners, 0, NULL);
	}
	return ret;
}

static void fs19xx_fault_work_fn(struct work_struct *work)
{
	fs19xx_gate(0);
}
static DECLARE_WORK(fs19xx_fault_work, fs19xx_fault_work_fn);

/* Callable under a codec mutex: physical mute runs outside that mutex. */
void q6apm_fs19xx_fault(void)
{
	atomic_set(&fs19xx_faulted, 1);
	atomic_set(&fs19xx_mode, 0);
	schedule_work(&fs19xx_fault_work);
}
EXPORT_SYMBOL_GPL(q6apm_fs19xx_fault);

int q6apm_fs19xx_register(struct notifier_block *listener, unsigned int position)
{
	int ret;

	if (!position || position > 8 || !is_power_of_2(position))
		return -EINVAL;
	guard(mutex)(&fs19xx_listeners_lock);
	if (atomic_read(&fs19xx_mode) || (fs19xx_positions & position))
		return -EBUSY;
	ret = blocking_notifier_chain_register(&fs19xx_listeners, listener);
	if (!ret)
		fs19xx_positions |= position;
	return ret;
}
EXPORT_SYMBOL_GPL(q6apm_fs19xx_register);

void q6apm_fs19xx_unregister(struct notifier_block *listener, unsigned int position)
{
	mutex_lock(&fs19xx_listeners_lock);
	atomic_set(&fs19xx_mode, 0);
	blocking_notifier_call_chain(&fs19xx_listeners, 0, NULL);
	blocking_notifier_chain_unregister(&fs19xx_listeners, listener);
	fs19xx_positions &= ~position;
	mutex_unlock(&fs19xx_listeners_lock);
	/* All codec workers are drained before their final unregister action. */
	flush_work(&fs19xx_fault_work);
}
EXPORT_SYMBOL_GPL(q6apm_fs19xx_unregister);

static void fs19xx_free_hash(void *context)
{
	crypto_free_shash(context);
}

int q6apm_fs19xx_init(struct q6apm *apm)
{
	struct q6apm_fs19xx *fs;
	int ret;

	if (!of_property_read_bool(apm->dev->of_node, "xiaomi,fs19xx-protected"))
		return 0;
	fs = devm_kzalloc(apm->dev, sizeof(*fs), GFP_KERNEL);
	if (!fs)
		return -ENOMEM;
	mutex_init(&fs->lock);
	fs->sha256 = crypto_alloc_shash("sha256", 0, 0);
	if (IS_ERR(fs->sha256))
		return PTR_ERR(fs->sha256);
	ret = devm_add_action_or_reset(apm->dev, fs19xx_free_hash, fs->sha256);
	if (ret)
		return ret;
	apm->fs19xx = fs;
	return 0;
}

static bool fs19xx_verify(void *context, unsigned int slot, const u8 *data, size_t bytes)
{
	struct q6apm_fs19xx *fs = context;
	SHASH_DESC_ON_STACK(desc, fs->sha256);
	u8 digest[32], expected[32];
	bool valid;

	desc->tfm = fs->sha256;
	if (hex2bin(expected, uke_fs19xx_parameters[slot].sha256, sizeof(expected)))
		return false;
	valid = !crypto_shash_digest(desc, data, bytes, digest) &&
		!memcmp(digest, expected, sizeof(digest));
	shash_desc_zero(desc);
	return valid;
}

static int fs19xx_control_info(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_info *info)
{
	info->type = SNDRV_CTL_ELEM_TYPE_BYTES;
	info->count = UKE_FS19XX_FRAME_BYTES;
	return 0;
}
static int fs19xx_control_get(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_value *value)
{
	/* alsactl and unprivileged clients must never read calibration back. */
	memset(value->value.bytes.data, 0, UKE_FS19XX_FRAME_BYTES);
	return 0;
}
static int fs19xx_control_put(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_value *value)
{
	struct snd_soc_component *component = snd_kcontrol_chip(kcontrol);
	struct q6apm *apm = dev_get_drvdata(component->dev);
	struct q6apm_fs19xx *fs = apm->fs19xx;
	int ret;

	if (!capable(CAP_SYS_RAWIO))
		return -EPERM;
	guard(mutex)(&fs->lock);
	if (fs->removing)
		return -ENODEV;
	ret = uke_fs19xx_provision(&fs->data, value->value.bytes.data,
		UKE_FS19XX_FRAME_BYTES, fs->owner != NULL, fs19xx_verify, fs);
	if (!ret && fs->data.status == UKE_FS_READY)
		atomic_set(&fs19xx_faulted, 0);
	/* The control core does not retain this write value; erase its copy too. */
	memzero_explicit(value->value.bytes.data, UKE_FS19XX_FRAME_BYTES);
	return ret ? ret : 1;
}
static const char * const fs19xx_state_names[] = {
	"Empty", "Staging", "Ready", "Prepared", "Running", "Fault",
};
static int fs19xx_state_info(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_info *info)
{
	return snd_ctl_enum_info(info, 1, ARRAY_SIZE(fs19xx_state_names), fs19xx_state_names);
}
static int fs19xx_state_get(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_value *value)
{
	struct snd_soc_component *component = snd_kcontrol_chip(kcontrol);
	struct q6apm *apm = dev_get_drvdata(component->dev);
	guard(mutex)(&apm->fs19xx->lock);
	value->value.enumerated.item[0] = atomic_read(&fs19xx_faulted) ? UKE_FS_FAULT : apm->fs19xx->data.status;
	return 0;
}
static const struct snd_kcontrol_new fs19xx_controls[] = {
	{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, .name = UKE_FS19XX_CONTROL,
	  .access = SNDRV_CTL_ELEM_ACCESS_READWRITE | SNDRV_CTL_ELEM_ACCESS_VOLATILE,
	  .info = fs19xx_control_info, .get = fs19xx_control_get, .put = fs19xx_control_put },
	{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, .name = UKE_FS19XX_STATUS,
	  .access = SNDRV_CTL_ELEM_ACCESS_READ | SNDRV_CTL_ELEM_ACCESS_VOLATILE,
	  .info = fs19xx_state_info, .get = fs19xx_state_get },
};
int q6apm_fs19xx_controls(struct snd_soc_component *component)
{
	struct q6apm *apm = dev_get_drvdata(component->dev);
	if (!apm->fs19xx)
		return 0;
	return snd_soc_add_component_controls(component, fs19xx_controls, ARRAY_SIZE(fs19xx_controls));
}

bool q6apm_fs19xx_graph(struct q6apm_graph *graph)
{
	return graph->apm->fs19xx && graph->id == 40;
}
EXPORT_SYMBOL_GPL(q6apm_fs19xx_graph);

int q6apm_fs19xx_claim(struct audioreach_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	struct audioreach_sub_graph *sg;
	struct audioreach_container *container;
	struct audioreach_module *module;
	unsigned int found = 0;
	int ret;

	if (!fs || graph->id != 40)
		return 0;
	guard(mutex)(&fs->lock);
	if (fs->removing || fs->owner || fs->data.status != UKE_FS_READY)
		return -ENODATA;
	list_for_each_entry(sg, &graph->info->sg_list, node) {
		list_for_each_entry(container, &sg->container_list, node) {
			if (container->capability_id != 0x0b001001 || container->proc_domain != 2 ||
			    container->graph_pos != 4)
				return -EINVAL;
			list_for_each_entry(module, &container->modules_list, node) {
				unsigned int bit, instance, destination;
				switch (module->module_id) {
				case UKE_FS19XX_RX_MODULE:
					if (module->instance_id != UKE_FS19XX_RX_IID ||
					    module->ctrl_link.first_instance != UKE_FS19XX_RX_IID ||
					    module->ctrl_link.second_instance != UKE_FS19XX_TX_IID ||
					    module->ctrl_link.first_port != 0x80000000 ||
					    module->ctrl_link.second_port != 0x80000000 ||
					    module->ctrl_link.intent != 0x08001231 ||
					    module->ctrl_link.heap != 1)
						return -EINVAL;
					bit = 1; break;
				case UKE_FS19XX_TX_MODULE:
					if (module->instance_id != UKE_FS19XX_TX_IID) return -EINVAL;
					bit = 2; break;
				case MODULE_ID_TDM_SINK: bit = 4; goto tdm;
				case MODULE_ID_TDM_SOURCE: bit = 8;
				tdm:
					if (module->hw_interface_type != 3 || module->hw_interface_idx ||
					    module->slot_mask != 15 || module->nslots_per_frame != 4 ||
					    module->slot_width != 32 || module->sync_src != 1 ||
					    module->data_format != 1 || module->ctrl_data_out_enable != 1 ||
					    module->sync_mode || module->ctrl_invert_sync_pulse ||
					    module->ctrl_sync_data_delay != 1 ||
					    module->active_lane_mask != (bit == 4 ? 2 : 1)) return -EINVAL;
					break;
				case MODULE_ID_MFC: bit = 16; break;
				default: return -EINVAL;
				}
				switch (bit) {
				case 1: instance = 0x4040; destination = 0x4433; break;
				case 2: instance = 0x49fd; destination = 0; break;
				case 4: instance = 0x4433; destination = 0; break;
				case 8: instance = 0x4960; destination = 0x49fd; break;
				default: instance = 0x442e; destination = 0x4040; break;
				}
				if (module->instance_id != instance || module->src_mod_inst_id != instance ||
				    module->max_ip_port != (bit == 8 ? 0 : 1) ||
				    module->max_op_port != (bit == 4 ? 0 : 1) ||
				    module->num_connections != (destination ? 1 : 0) ||
				    sg->direction != ((bit == 2 || bit == 8) ? 2 : 1) ||
				    (bit != 1 && module->ctrl_link.first_instance))
					return -EINVAL;
				if (destination && (module->src_mod_op_port_id[0] != 1 ||
				    module->dst_mod_inst_id[0] != destination || module->dst_mod_ip_port_id[0] != 2))
					return -EINVAL;
				if (found & bit) return -EINVAL;
				found |= bit;
			}
		}
	}
	if (found != 31)
		return -EINVAL;
	ret = fs19xx_gate(0);
	if (!ret)
		fs->owner = graph;
	return ret;
}

static int fs19xx_send(void *context, u32 instance, u32 parameter, const u8 *data, size_t bytes)
{
	struct q6apm_graph *graph = context;
	struct apm_module_param_data *header;
	struct gpr_pkt *pkt;
	int ret;

	if (!bytes || bytes > 5360)
		return -EINVAL;
	pkt = audioreach_alloc_apm_cmd_pkt(ALIGN(sizeof(*header) + bytes, 8), APM_CMD_SET_CFG, 0);
	if (IS_ERR(pkt))
		return PTR_ERR(pkt);
	header = (void *)pkt + GPR_HDR_SIZE + APM_CMD_HDR_SIZE;
	header->module_instance_id = instance;
	header->param_id = parameter;
	header->param_size = bytes;
	header->error_code = 0;
	memcpy(header + 1, data, bytes);
	ret = q6apm_send_cmd_sync(graph->apm, pkt, 0);
	memzero_explicit(header + 1, bytes);
	kfree(pkt);
	return ret;
}

int q6apm_fs19xx_prepare(struct q6apm_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	/* Stock VI endpoint channel types 48..51, four 32-bit channels. */
	static const u8 vi_map[10] = {4, 0, 48, 0, 49, 0, 50, 0, 51, 0};
	int ret;
	if (!q6apm_fs19xx_graph(graph)) return 0;
	guard(mutex)(&fs->lock);
	if (fs->removing || fs->owner != graph->ar_graph) return -ENODEV;
	fs19xx_gate(0);
	ret = fs19xx_send(graph, 0x4960, 0x0800108a, vi_map, sizeof(vi_map));
	if (fs->data.status == UKE_FS_PREPARED)
		fs->data.status = UKE_FS_READY;
	if (!ret) ret = uke_fs19xx_prepare(&fs->data, fs19xx_send, graph);
	if (ret) {
		uke_fs19xx_erase(&fs->data);
		fs->data.status = UKE_FS_FAULT;
	}
	return ret;
}

int q6apm_fs19xx_prepared(struct q6apm_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	if (!q6apm_fs19xx_graph(graph)) return 0;
	guard(mutex)(&fs->lock);
	if (fs->data.status != UKE_FS_PREPARED) return -ENODATA;
	return fs19xx_gate(1);
}
int q6apm_fs19xx_started(struct q6apm_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	int ret;
	if (!q6apm_fs19xx_graph(graph)) return 0;
	guard(mutex)(&fs->lock);
	if (fs->removing || fs->data.status != UKE_FS_PREPARED) return -ENODATA;
	ret = fs19xx_gate(2);
	if (!ret) fs->data.status = UKE_FS_RUNNING;
	return ret;
}
void q6apm_fs19xx_stopped(struct q6apm_graph *graph, bool failed)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	if (!q6apm_fs19xx_graph(graph)) return;
	guard(mutex)(&fs->lock);
	fs19xx_gate(0);
	if (failed) {
		uke_fs19xx_erase(&fs->data);
		fs->data.status = UKE_FS_FAULT;
	} else if (fs->data.status == UKE_FS_RUNNING) {
		fs->data.status = UKE_FS_PREPARED;
	}
}
void q6apm_fs19xx_quiesce(struct audioreach_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	if (!fs || graph->id != 40) return;
	guard(mutex)(&fs->lock);
	fs19xx_gate(0);
}
void q6apm_fs19xx_release(struct audioreach_graph *graph)
{
	struct q6apm_fs19xx *fs = graph->apm->fs19xx;
	if (!fs || graph->id != 40) return;
	guard(mutex)(&fs->lock);
	fs19xx_gate(0);
	if (fs->owner == graph) fs->owner = NULL;
	if (graph->state < 0) {
		uke_fs19xx_erase(&fs->data);
		fs->data.status = UKE_FS_FAULT;
	} else if (!fs->removing && (fs->data.status == UKE_FS_PREPARED || fs->data.status == UKE_FS_RUNNING))
		fs->data.status = UKE_FS_READY;
}
void q6apm_fs19xx_shutdown(struct q6apm *apm)
{
	struct q6apm_fs19xx *fs = apm->fs19xx;
	if (!fs) return;
	guard(mutex)(&fs->lock);
	fs->removing = true;
	fs19xx_gate(0);
	uke_fs19xx_erase(&fs->data);
}
