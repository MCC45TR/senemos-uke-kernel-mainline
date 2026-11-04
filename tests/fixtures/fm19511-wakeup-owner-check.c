/* SPDX-License-Identifier: GPL-2.0-only */
/* Linux callbacks are extracted unchanged; all device and bus effects are mocks. */
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef uint8_t u8;
typedef uint64_t u64;
typedef struct { int value; } atomic_t;
typedef struct { uint64_t value; } atomic64_t;
typedef int wait_queue_head_t;
struct wakeup_source { int unused; };
struct device;
struct wake_irq { struct device *dev; int irq; bool dedicated; };
struct device {
 struct { bool can_wakeup; struct wakeup_source *wakeup; struct wake_irq *wakeirq; int lock; } power;
 bool wakeup_property;
};
struct i2c_adapter { bool capable; };
struct i2c_client { struct device dev; struct i2c_adapter *adapter; int irq; unsigned int flags; void *data; };
struct mutex { bool locked; };
struct kref { unsigned int count; };
struct delayed_work { int unused; };
struct file_operations { int unused; };
struct miscdevice { int minor; const char *name; const struct file_operations *fops; struct device *parent; int mode; };
struct regulator { bool enabled; };
struct fm19511;
#define GFP_KERNEL 0
#define I2C_CLIENT_WAKE 0x80
#define I2C_FUNC_I2C 1
#define IRQF_TRIGGER_FALLING 2
#define MISC_DYNAMIC_MINOR 255
#define EPROBE_DEFER 517
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define kzalloc_obj(obj) calloc(1,sizeof(obj))
#define spin_lock_irq(p) assert((p)!=NULL)
#define spin_unlock_irq(p) assert((p)!=NULL)
#define spin_lock_irqsave(p,f) do {assert((p)!=NULL);(f)=0;} while(0)
#define spin_unlock_irqrestore(p,f) do {assert((p)!=NULL);(void)(f);} while(0)
#define dev_WARN_ONCE(dev,condition,...) (!!(condition))
#define dev_dbg(...) ((void)0)
#define INIT_DELAYED_WORK(work,callback) ((void)(work))
#include "struct.inc"

static const struct file_operations fm19511_fops;
static const int root_node;
static const int *const of_root=&root_node;
static bool admitted=true,fail_alloc;
static int fail_config,fail_irq,fail_misc,fail_voltage,wake_irq_number;
static unsigned int irq_live,misc_live,ws_live,tag_live;
static struct regulator regulator;
static void (*power_cleanup)(void *);
static void *power_cleanup_data;
static void device_wakeup_attach_irq(struct device *dev,struct wake_irq *irq)
{assert(dev&&irq&&dev->power.wakeirq==irq);}
static const char *dev_name(struct device *dev){assert(dev);return "5-0057";}
static bool pm_sleep_transition_in_progress(void){return false;}
static void device_set_wakeup_capable(struct device *dev,bool value){dev->power.can_wakeup=value;}
static struct wakeup_source *wakeup_source_register(struct device *dev,const char *name)
{assert(dev&&name);struct wakeup_source *ws=calloc(1,sizeof(*ws));assert(ws);ws_live++;return ws;}
static void wakeup_source_unregister(struct wakeup_source *ws){assert(ws&&ws_live);ws_live--;free(ws);}
static void device_wakeup_disable(struct device *dev)
{if(dev->power.wakeup){wakeup_source_unregister(dev->power.wakeup);dev->power.wakeup=NULL;}}
static void *active_tag;
static void *kzalloc(size_t size,int flags)
{(void)flags;if(fail_alloc)return NULL;assert(size==sizeof(struct fm19511));void *p=calloc(1,size);assert(p);active_tag=p;tag_live++;return p;}
static void kfree(void *p)
{if(p==active_tag){assert(tag_live==1);tag_live--;active_tag=NULL;}free(p);}
#include "attach.inc"
#include "enable.inc"
#include "init.inc"
#include "attach-irq.inc"
#include "set-irq.inc"
static void dev_pm_clear_wake_irq(struct device *dev){free(dev->power.wakeirq);dev->power.wakeirq=NULL;}
static int dev_pm_set_dedicated_wake_irq(struct device *dev,int irq)
{int ret=dev_pm_set_wake_irq(dev,irq);if(!ret)dev->power.wakeirq->dedicated=true;return ret;}
static int fwnode_irq_get_byname(void *node,const char *name)
{assert(node&&!strcmp(name,"wakeup"));return wake_irq_number;}
static int dev_err_probe(struct device *dev,int error,const char *text)
{assert(dev&&text);return error;}
#define dev_warn(...) ((void)0)
static int core_prepare(struct i2c_client *client)
{
 struct device *dev=&client->dev;
 void *fwnode=client;
 int status=0;
#include "core.inc"
 return status;
put_sync_adapter:
 return status;
}
static bool of_machine_is_compatible(const char *name){assert(name);return admitted;}
static int of_property_read_string(const int *node,const char *key,const char **value)
{assert(node==of_root&&!strcmp(key,"model"));*value="POCO Pad X1";return 0;}
static bool device_property_read_bool(struct device *dev,const char *name)
{assert(!strcmp(name,"wakeup-source"));return dev->wakeup_property;}
static bool device_can_wakeup(struct device *dev){return dev->power.can_wakeup;}
static bool i2c_check_functionality(struct i2c_adapter *adapter,int mask)
{assert(mask==I2C_FUNC_I2C);return adapter->capable;}
static struct regulator *devm_regulator_get(struct device *dev,const char *name)
{assert(dev&&!strcmp(name,"vdd"));return &regulator;}
static int regulator_set_voltage(struct regulator *supply,int low,int high)
{assert(supply==&regulator&&low==3300000&&high==3300000);return fail_voltage;}
static int regulator_enable(struct regulator *supply){assert(supply==&regulator&&!supply->enabled);supply->enabled=true;return 0;}
static void regulator_disable(struct regulator *supply){assert(supply==&regulator&&supply->enabled);supply->enabled=false;}
static int devm_add_action_or_reset(struct device *dev,void (*action)(void *),void *data)
{assert(dev&&!power_cleanup);power_cleanup=action;power_cleanup_data=data;return 0;}
static void mutex_init(struct mutex *lock){lock->locked=false;}
static void mutex_lock(struct mutex *lock){assert(!lock->locked);lock->locked=true;}
static void mutex_unlock(struct mutex *lock){assert(lock->locked);lock->locked=false;}
static void kref_init(struct kref *refs){refs->count=1;}
static void kref_put(struct kref *refs,void (*release)(struct kref *))
{assert(refs->count);if(!--refs->count)release(refs);}
static void init_waitqueue_head(wait_queue_head_t *queue){*queue=0;}
static void atomic_set(atomic_t *value,int n){value->value=n;}
static void atomic64_set(atomic64_t *value,u64 n){value->value=n;}
static void usleep_range(unsigned int low,unsigned int high){assert(low==5000&&high==5100);}
static int fm19511_configure(struct fm19511 *tag){assert(tag&&regulator.enabled);return fail_config;}
static int fm19511_irq(int irq,void *tag){(void)irq;(void)tag;return 0;}
static int request_irq(int irq,int (*handler)(int,void *),unsigned long flags,const char *name,void *tag)
{assert(irq==170&&handler==fm19511_irq&&flags==IRQF_TRIGGER_FALLING&&!strcmp(name,"fm19511-uke")&&tag);if(fail_irq)return fail_irq;assert(!irq_live);irq_live++;return 0;}
static void free_irq(int irq,void *tag){assert(irq==170&&tag&&irq_live==1);irq_live--;}
static void cancel_delayed_work_sync(struct delayed_work *work){assert(work);}
static void i2c_set_clientdata(struct i2c_client *client,void *data){client->data=data;}
static void *i2c_get_clientdata(struct i2c_client *client){return client->data;}
static int misc_register(struct miscdevice *misc)
{assert(!strcmp(misc->name,"fm-ntag")&&misc->fops==&fm19511_fops&&misc->parent&&misc->mode==0600);if(fail_misc)return fail_misc;assert(!misc_live);misc_live++;return 0;}
static void misc_deregister(struct miscdevice *misc){assert(misc&&misc_live==1);misc_live--;}
static void wake_up_interruptible(wait_queue_head_t *queue){assert(queue);}
#include "free.inc"
#include "power_off.inc"
#include "probe.inc"
#include "remove.inc"

static void core_cleanup(struct i2c_client *client)
{
 dev_pm_clear_wake_irq(&client->dev);
 device_init_wakeup(&client->dev,false);
 if(power_cleanup){power_cleanup(power_cleanup_data);power_cleanup=NULL;power_cleanup_data=NULL;}
 assert(!irq_live&&!misc_live&&!ws_live&&!tag_live&&!regulator.enabled);
}
static void cycle(bool wake,bool dedicated,int failure)
{
 struct i2c_adapter adapter={.capable=true};
 struct i2c_client client={.dev={.wakeup_property=wake},.adapter=&adapter,.irq=170,.flags=wake?I2C_CLIENT_WAKE:0};
 fail_alloc=failure==1;fail_config=failure==2?-EREMOTEIO:0;fail_irq=failure==3?-EBUSY:0;
 fail_misc=failure==4?-EIO:0;fail_voltage=failure==5?-ERANGE:0;
 wake_irq_number=dedicated?175:0;
 assert(!core_prepare(&client));
 struct wakeup_source *original_source=client.dev.power.wakeup;
 struct wake_irq *original_irq=client.dev.power.wakeirq;
 assert(!!original_source==wake&&!!original_irq==wake);
 if(wake)assert(original_irq->irq==(dedicated?175:170));
 int ret=fm19511_probe(&client);
 if(EXPECT_BEFORE&&wake&&failure==0){
  assert(ret==-EEXIST&&!irq_live&&!misc_live&&!tag_live);
  assert(client.dev.power.wakeup==original_source&&client.dev.power.wakeirq==original_irq);
 } else if(!failure){
  assert(ret==0&&misc_live==1&&irq_live==1&&tag_live==1);
  assert(client.dev.power.wakeup==original_source&&client.dev.power.wakeirq==original_irq);
  fm19511_remove(&client);
  if(!EXPECT_BEFORE)assert(client.dev.power.wakeup==original_source&&client.dev.power.wakeirq==original_irq);
 } else {
  static const int expected[]={0,-ENOMEM,-EREMOTEIO,-EBUSY,-EIO,-ERANGE};
  assert(ret==expected[failure]);
  assert(client.dev.power.wakeup==original_source&&client.dev.power.wakeirq==original_irq);
 }
 core_cleanup(&client);
}
int main(void)
{
 cycle(false,false,0);
 cycle(true,false,0);
 cycle(true,true,0);
 if(!EXPECT_BEFORE){
  for(int failure=1;failure<=5;failure++){cycle(false,false,failure);cycle(true,false,failure);cycle(true,true,failure);}
  for(unsigned int i=0;i<64;i++)cycle(true,i%2,0);
 }
 puts(EXPECT_BEFORE?"Actual before probe reproduces I2C-owned wakeup EEXIST; property-absent control passes.":
      "Actual corrected probe/remove preserve I2C wake source and shared/dedicated IRQ ownership; failure cleanup and 64 cycles pass.");
 return 0;
}
