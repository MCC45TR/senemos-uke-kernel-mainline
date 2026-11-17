// SPDX-License-Identifier: GPL-2.0-only
/* Actual power/dispatch/provider callbacks; modeled framework, no hardware. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#define EPROBE_DEFER 517
#define BIT(n) (1U << (n))
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define READ_ONCE(x) (x)
#define GFP_KERNEL 0
#define OF_DYNAMIC 1
#define IS_ERR(p) ((intptr_t)(p)<0 && (intptr_t)(p)>-4096)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define dev_err(...) do {} while (0)
enum { CAMSS_7675, CAMSS_8550, CAMSS_8650, CAMSS_8x16 };
struct device_node {bool dynamic;};
struct device_driver {void *owner;bool suppress_bind_attrs;};
struct device {struct device_node *of_node;struct device_driver *driver;};
struct mutex {bool held;};
struct regulator {int id,refs,enabled,min,max,load;};
struct regulator_bulk_data {const char *supply;struct regulator *consumer;int init_load_uA;};
struct csiphy_device;
struct csiphy_hw_ops {void (*reset)(struct csiphy_device *);void (*hw_version_read)(struct csiphy_device *,struct device *);};
struct csiphy_supply_voltage {unsigned min_uV,max_uV;};
struct csiphy_subdev_resources {struct csiphy_supply_voltage voltage[2];const struct csiphy_hw_ops *hw_ops;};
struct camss_subdev_resources {struct regulator_bulk_data regulators[3];struct csiphy_subdev_resources csiphy;};
struct camss_resources {unsigned version;};
struct camss {struct device *dev;struct camss_resources *res;};
struct v4l2_subdev {struct csiphy_device *priv;};
struct csiphy_sm7675_power;
struct csiphy_device {struct camss *camss;struct v4l2_subdev subdev;int num_supplies,nclocks,irq;void *clock;struct regulator_bulk_data *supplies;const struct csiphy_subdev_resources *res;struct csiphy_sm7675_power *uke_power;};
static struct {int fault;} cam_cc_power;
static struct {bool ready,synchronized;} cam_cc_native;
#include "actual-status.h"
static struct regulator rails[2];
static struct device_node node;
static struct device_driver driver;
static struct device dev;
static struct camss_resources resources;
static struct camss camss;
static struct csiphy_device phy;
static unsigned calls,inject,operations,model_get_refs,model_put_refs,allocs,frees,pm,clocks,irq;
static bool strict,board,trace,conflict,fail_alloc,fail_action,fail_disable_provider;
static void (*action)(void *);
static void *action_data;
static bool step(const char *name,int id,int a,int b)
{
	operations++;
	if(trace)printf("%s %d %d %d\n",name,id,a,b);
	return ++calls==inject;
}
static void event(const char *name){operations++;if(trace)printf("%s\n",name);}
static bool of_machine_is_compatible(const char *s){assert(!strcmp(s,"xiaomi,uke"));return board;}
static bool of_node_check_flag(struct device_node *n,int flag){assert(flag==OF_DYNAMIC);return n->dynamic;}
static void mutex_init(struct mutex *m){m->held=false;}
static void mutex_lock(struct mutex *m){assert(!m->held);m->held=true;}
static void mutex_unlock(struct mutex *m){assert(m->held);m->held=false;}
static void *kzalloc(size_t n,int flags){assert(!flags);if(fail_alloc)return NULL;allocs++;return calloc(1,n);}
static void kfree(void *p){assert(p);frees++;free(p);}
static struct device *get_device(struct device *d){assert(d==&dev);model_get_refs++;return d;}
static void put_device(struct device *d){assert(d==&dev && model_get_refs>model_put_refs);model_put_refs++;}
static struct regulator *regulator_get(struct device *d,const char *s)
{
	assert(d==&dev);int id=!strcmp(s,"vdd-csiphy-1p2");
	assert(id||!strcmp(s,"vdd-csiphy-0p9"));
	if(step("get",id,0,0))return ERR_PTR(-EPROBE_DEFER);
	rails[id].refs++;return &rails[id];
}
static void regulator_put(struct regulator *r){assert(r->refs>0&&!r->enabled&&!r->min&&!r->load);r->refs--;event("put");}
static int devm_add_action_or_reset(struct device *d,void(*fn)(void *),void *p)
{
	assert(d==&dev && !action);if(fail_action){fn(p);return -ENOMEM;}action=fn;action_data=p;return 0;
}
static int qcom_sm7675_camcc_status(void)
{
	if(step("cached-status",0,0,0))cam_cc_power.fault=-EIO;
	return actual_qcom_sm7675_camcc_status();
}
static int pm_runtime_resume_and_get(struct device *d){assert(d==&dev);if(step("pm-get",0,0,0))return -EIO;pm++;return 0;}
static int pm_runtime_put_sync(struct device *d){assert(d==&dev && pm);pm--;return step("pm-put",0,0,0)?-EIO:0;}
static void pm_runtime_get_noresume(struct device *d){assert(d==&dev);pm++;event("pm-retain");}
static int csiphy_set_clock_rates(struct csiphy_device *p){assert(p==&phy);return step("rates",0,0,0)?-EINVAL:0;}
static int regulator_set_voltage(struct regulator *r,int min,int max)
{
	bool bad=step("voltage",r->id,min,max);
	if(!min){assert(!rails[0].enabled&&!rails[1].enabled);assert(max==INT_MAX);}
	else if(r->id==0&&conflict)return -EINVAL;
	r->min=min;r->max=min?max:0;
	/* Model a failed write with an uncertain postcondition. */
	return bad?-EIO:0;
}
static int regulator_set_load(struct regulator *r,int load){bool bad=step("load",r->id,load,0);if(!load)assert(!rails[0].enabled&&!rails[1].enabled);r->load=load;return bad?-EIO:0;}
static int regulator_enable(struct regulator *r)
{
	if(strict){assert(rails[0].min==880000&&rails[0].max==912000);assert(rails[1].min==1200000&&rails[1].max==1200000);}
	bool bad=step("enable",r->id,0,0);r->enabled++;return bad?-EIO:0;
}
static int regulator_disable(struct regulator *r){assert(r->enabled>0&&!clocks&&!irq);if(step("disable",r->id,0,0))return -EIO;r->enabled--;return 0;}
static int camss_enable_clocks(int n,void *c,struct device *d){assert(n==2&&!c&&d==&dev);if(step("clocks-on",0,0,0))return -EIO;clocks++;return 0;}
static void camss_disable_clocks(int n,void *c){assert(n==2&&!c&&clocks&&!irq);clocks--;event("clocks-off");if(fail_disable_provider)cam_cc_power.fault=-EIO;}
static void enable_irq(int n){assert(n==7&&clocks&&!irq);irq++;event("irq-on");}
static void disable_irq(int n){assert(n==7&&irq);irq--;event("irq-off");}
static void reset(struct csiphy_device *p){assert(p==&phy&&irq&&clocks);event("reset");}
static void version(struct csiphy_device *p,struct device *d){assert(p==&phy&&d==&dev&&irq&&clocks);event("version");}
static const struct csiphy_hw_ops hw_ops={reset,version};
#include "actual-policy.h"
static struct csiphy_device *v4l2_get_subdevdata(struct v4l2_subdev *s){return s->priv;}
static int regulator_bulk_enable(int n,struct regulator_bulk_data *s)
{
	assert(n==2);if(strict)assert(rails[0].min==880000&&rails[1].min==1200000);
	if(step("bulk-on",0,0,0))return -EIO;for(int i=0;i<n;i++)s[i].consumer->enabled++;return 0;
}
static int regulator_bulk_disable(int n,struct regulator_bulk_data *s){assert(n==2);event("bulk-off");for(int i=0;i<n;i++){assert(s[i].consumer->enabled);s[i].consumer->enabled--;}return 0;}
#include "actual-power.h"
#include "actual-dispatch.h"

static void setup(unsigned ver)
{
	memset(rails,0,sizeof(rails));for(int i=0;i<2;i++)rails[i].id=i;
	calls=inject=operations=model_get_refs=model_put_refs=allocs=frees=pm=clocks=irq=0;
	board=true;strict=true;conflict=fail_alloc=fail_action=fail_disable_provider=false;
	cam_cc_power.fault=0;cam_cc_native.ready=true;cam_cc_native.synchronized=false;
	node=(struct device_node){0};driver=(struct device_driver){NULL,true};dev=(struct device){&node,&driver};
	resources=(struct camss_resources){ver};camss=(struct camss){&dev,&resources};
	phy=(struct csiphy_device){.camss=&camss,.num_supplies=2,.nclocks=2,.irq=7,.res=&policy.csiphy};phy.subdev.priv=&phy;
	action=NULL;action_data=NULL;
}
static void create(void)
{
	assert(csiphy_sm7675_owner_check(&camss)==0);
	assert(csiphy_sm7675_power_init(&phy,&policy)==0);
	assert(phy.uke_power && model_get_refs==1&&rails[0].refs==1&&rails[1].refs==1);
	calls=operations=0;
}
/* Tests simulate reboot only after verifying that production retained ownership. */
static void reboot_model(void){if(action_data)free(action_data);action=NULL;action_data=NULL;}
static void healthy(void)
{
	setup(CAMSS_7675);create();
	assert(policy.csiphy.voltage[0].min_uV==880000&&policy.csiphy.voltage[0].max_uV==912000);
	assert(policy.csiphy.voltage[1].min_uV==1200000&&policy.csiphy.voltage[1].max_uV==1200000);
	assert(policy.regulators[0].init_load_uA==98480&&policy.regulators[1].init_load_uA==17920);
	assert(csiphy_set_power(&phy.subdev,1)==0&&pm==1&&clocks==1&&irq==1);
	unsigned n=operations;assert(csiphy_set_power(&phy.subdev,1)==0&&operations==n+1);
	assert(csiphy_set_power(&phy.subdev,0)==0);
	assert(!pm&&!clocks&&!irq&&!rails[0].enabled&&!rails[1].enabled);
	assert(!rails[0].min&&!rails[1].min&&!rails[0].load&&!rails[1].load);
	n=operations;assert(csiphy_set_power(&phy.subdev,0)==0&&operations==n);
	action(action_data);action_data=NULL;
	assert(model_put_refs==model_get_refs&&frees==allocs&&!rails[0].refs&&!rails[1].refs);
}
static unsigned fault_cases(void)
{
	unsigned count=0;
	/* Enumerate every fallible call in the real first-on/last-off paths. */
	setup(CAMSS_7675);create();assert(!csiphy_set_power(&phy.subdev,1));unsigned on_count=calls;
	assert(!csiphy_set_power(&phy.subdev,0));unsigned total=calls;action(action_data);action_data=NULL;
	for(unsigned phase=0;phase<2;phase++)for(unsigned at=1;at<=(phase?total-on_count:on_count);at++){
		setup(CAMSS_7675);create();
		if(phase)assert(!csiphy_set_power(&phy.subdev,1));
		calls=0;inject=at;
		int ret=csiphy_set_power(&phy.subdev,phase?0:1);assert(ret<0);
		if(phy.uke_power->fault){
			assert(!irq);unsigned n=operations;
			assert(csiphy_set_power(&phy.subdev,0)==ret&&csiphy_set_power(&phy.subdev,1)==ret&&operations==n);
			action(action_data);assert(frees==0&&model_put_refs==0&&rails[0].refs==1&&rails[1].refs==1);
		}else{assert(!pm&&!rails[0].enabled&&!rails[1].enabled);action(action_data);action_data=NULL;assert(frees==1);}
		reboot_model();count++;
	}
	setup(CAMSS_7675);create();assert(!csiphy_set_power(&phy.subdev,1));fail_disable_provider=true;
	assert(csiphy_set_power(&phy.subdev,0)==-EIO);assert(pm==1&&rails[0].enabled==1&&rails[1].enabled==1&&rails[0].min==880000);
	action(action_data);assert(!frees);reboot_model();count++;
	setup(CAMSS_7675);create();conflict=true;
	assert(csiphy_set_power(&phy.subdev,1)==-EINVAL);
	assert(!rails[0].enabled&&!rails[1].enabled&&!rails[0].min&&!clocks);
	action(action_data);assert(!frees);reboot_model();count++;
	return count;
}
static void admission(void)
{
	setup(CAMSS_7675);board=false;assert(csiphy_sm7675_owner_check(&camss)==-EINVAL);board=true;
	node.dynamic=true;assert(csiphy_sm7675_owner_check(&camss)==-EINVAL);node.dynamic=false;
	driver.owner=&driver;assert(csiphy_sm7675_owner_check(&camss)==-EINVAL);driver.owner=NULL;
	driver.suppress_bind_attrs=false;assert(csiphy_sm7675_owner_check(&camss)==-EINVAL);driver.suppress_bind_attrs=true;
	dev.of_node=NULL;assert(csiphy_sm7675_owner_check(&camss)==-EINVAL);dev.of_node=&node;
	dev.driver=NULL;assert(csiphy_sm7675_owner_check(&camss)==-EINVAL);dev.driver=&driver;
	cam_cc_native.ready=false;assert(csiphy_sm7675_owner_check(&camss)==-EPROBE_DEFER);
	cam_cc_native.ready=true;assert(!csiphy_sm7675_owner_check(&camss));
	cam_cc_power.fault=-EIO;assert(actual_qcom_sm7675_camcc_status()==-EIO);cam_cc_native.ready=false;
	assert(actual_qcom_sm7675_camcc_status()==-EIO);assert(!model_get_refs&&!allocs&&!pm);
	for(unsigned at=1;at<=2;at++){
		setup(CAMSS_7675);inject=at;assert(csiphy_sm7675_power_init(&phy,&policy)==-EPROBE_DEFER);
		assert(model_get_refs==model_put_refs&&allocs==frees&&!rails[0].refs&&!rails[1].refs);
	}
	setup(CAMSS_7675);fail_alloc=true;assert(csiphy_sm7675_power_init(&phy,&policy)==-ENOMEM&&!model_get_refs);
	setup(CAMSS_7675);fail_action=true;assert(csiphy_sm7675_power_init(&phy,&policy)==-ENOMEM);
	assert(model_get_refs==model_put_refs&&allocs==frees&&!rails[0].refs&&!rails[1].refs);
	setup(CAMSS_7675);phy.num_supplies=1;assert(csiphy_sm7675_power_init(&phy,&policy)==-EINVAL&&!model_get_refs);
}
static void legacy(void)
{
	static struct regulator_bulk_data s[2];
	for(unsigned ver=CAMSS_8550;ver<=CAMSS_8x16;ver++)for(unsigned at=0;at<=4;at++){
		setup(ver);strict=false;trace=true;
		for(int i=0;i<2;i++)s[i]=(struct regulator_bulk_data){.consumer=&rails[i]};phy.supplies=s;
		inject=at;printf("case %u %u\n",ver,at);int ret=csiphy_set_power(&phy.subdev,1);printf("result %d\n",ret);
		if(!ret)assert(!csiphy_set_power(&phy.subdev,0));
		assert(!pm&&!clocks&&!irq&&!model_get_refs&&!allocs);
	}
	trace=false;
}
int main(int argc,char **argv)
{
	if(argc==2&&!strcmp(argv[1],"--legacy")){legacy();return 0;}
	if(argc==2&&!strcmp(argv[1],"--before")){
		setup(CAMSS_7675);static struct regulator_bulk_data s[2];for(int i=0;i<2;i++)s[i].consumer=&rails[i];phy.supplies=s;
		assert(!csiphy_set_power(&phy.subdev,1));return 0;
	}
	assert(argc==1);healthy();admission();unsigned n=fault_cases();
	printf("PASS: PHY power: healthy first-on/last-off, %u injected transition faults, cached admission, retained ownership and zero idle votes; no hardware\n",n);
	return 0;
}
