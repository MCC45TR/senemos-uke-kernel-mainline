#!/usr/bin/env bash
# Host-only boundary fixture for actual role-class functions. Deferred here.
set -Eeuo pipefail
kernel=${1:?Pass prepared Linux source}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
source_file=$kernel/drivers/usb/roles/class.c
extract() {
    UKE_ROLE_PATTERN="$1" awk 'BEGIN {pattern=ENVIRON["UKE_ROLE_PATTERN"]}
        $0 ~ pattern {emit=1; found=1} emit {print} emit && /^}/ {exit}
        END {if (!found) exit 2}' "$2"
}
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
typedef unsigned short umode_t;
struct lock_class_key { int unused; };
struct mutex { int unused; };
struct module { int unused; };
struct fwnode_handle { int unused; };
struct kobject { int unused; };
struct attribute { umode_t mode; };
struct device_attribute { struct attribute attr; };
struct device_driver { struct module *owner; };
struct device {
 struct kobject kobj;
 struct device *parent;
 void *fwnode;
 const void *class, *type;
 struct device_driver *driver;
 void *data;
};
enum usb_role { USB_ROLE_NONE, USB_ROLE_HOST, USB_ROLE_DEVICE };
struct usb_role_switch;
typedef int (*usb_role_switch_set_t)(struct usb_role_switch *, enum usb_role);
typedef enum usb_role (*usb_role_switch_get_t)(struct usb_role_switch *);
#define container_of(p,t,m) ((t *)((char *)(p)-offsetof(t,m)))
#define kobj_to_dev(p) container_of(p,struct device,kobj)
#define to_role_switch(p) container_of(p,struct usb_role_switch,dev)
#define IS_ERR_OR_NULL(p) (!(p) || (uintptr_t)(p) > (uintptr_t)-4096)
#define ERR_PTR(e) ((void *)(intptr_t)(e))
#define kzalloc_obj(o) calloc(1,sizeof(o))
#define mutex_lock(p) ((void)(p))
#define mutex_unlock(p) ((void)(p))
#define mutex_init_with_key(p,k) ((void)(p),(void)(k))
#define lockdep_register_key(k) ((void)(k))
#define dev_set_drvdata(d,p) ((d)->data=(p))
#define dev_set_name(d,f,...) ((void)(d),(void)(f))
#define dev_name(d) "fixture"
#define device_register(d) ((void)(d),0)
#define put_device(d) ((void)(d))
#define dev_fwnode(d) ((d)->fwnode)
#define component_add(d,o) ((void)(d),(void)(o),0)
#define dev_warn(...) ((void)0)
#define KOBJ_CHANGE 0
static int uevents, setter_calls, parser_calls, callback_error;
#define kobject_uevent(k,a) ((void)(k),(void)(a),uevents++)
#define DEVICE_ATTR_RW(n) struct device_attribute dev_attr_##n={.attr={.mode=0644}}
static const int role_class, usb_role_dev_type, connector_ops;
static enum usb_role observed;
static int match_string(const char *const *names, size_t count, const char *buf) {
 char value[32]; size_t len=strcspn(buf,"\n"); parser_calls++;
 if(len>=sizeof(value)) return -EINVAL;
 memcpy(value,buf,len); value[len]=0;
 for(size_t i=0;i<count;i++) if(!strcmp(value,names[i])) return (int)i;
 return -EINVAL;
}
#define sysfs_match_string(a,b) match_string(a,sizeof(a)/sizeof((a)[0]),b)
static int kstrtobool(const char *s,bool *value) {
 if(!strcmp(s,"0") || !strcmp(s,"false")) { *value=false; return 0; }
 return -EINVAL;
}
C
extract '^struct usb_role_switch_desc \{' "$kernel/include/linux/usb/role.h"
extract '^struct usb_role_switch \{' "$source_file"
extract '^int usb_role_switch_set_role\(' "$source_file"
extract '^enum usb_role usb_role_switch_get_role\(' "$source_file"
awk '/^static const char .*usb_roles\[\]/ {emit=1;found=1} emit {print} emit && /^};/ {exit} END {if(!found) exit 2}' "$source_file"
printf 'static ssize_t\n'
extract '^role_show\(' "$source_file"
extract '^static ssize_t role_store\(' "$source_file"
printf 'static DEVICE_ATTR_RW(role);\nstatic umode_t\n'
extract '^usb_role_switch_is_visible\(' "$source_file"
printf 'struct usb_role_switch *\n'
extract '^usb_role_switch_register\(' "$source_file"
cat <<'C'
static int setter(struct usb_role_switch *sw,enum usb_role role) {
 (void)sw; (void)role; setter_calls++; return callback_error;
}
static enum usb_role getter(struct usb_role_switch *sw) { (void)sw; return observed; }
int main(void) {
 struct device_driver driver={0}; struct device parent={.driver=&driver};
 struct usb_role_switch_desc desc={.set=setter,.get=getter,.allow_userspace_observation=true};
 struct usb_role_switch *sw=usb_role_switch_register(&parent,&desc);
 struct attribute foreign={.mode=0666}; char buf[32];
 const char *requests[]={"host","device","none","0","false","invalid","host\n"};
 assert(!IS_ERR_OR_NULL(sw) && sw->allow_userspace_observation && !sw->allow_userspace_control);
 assert(usb_role_switch_is_visible(&sw->dev.kobj,&dev_attr_role.attr,0)==0444);
 assert(usb_role_switch_is_visible(&sw->dev.kobj,&foreign,0)==0);
 for(size_t i=0;i<sizeof(requests)/sizeof(requests[0]);i++)
  assert(role_store(&sw->dev,&dev_attr_role,requests[i],strlen(requests[i]))==-EACCES);
 assert(setter_calls==0 && parser_calls==0 && uevents==0);
 observed=USB_ROLE_DEVICE;
 assert(role_show(&sw->dev,&dev_attr_role,buf)==7 && !strcmp(buf,"device\n"));
 /* Firmware/kernel callers retain control; a SET ACK does not change getter state. */
 assert(usb_role_switch_set_role(sw,USB_ROLE_HOST)==0 && setter_calls==1 && uevents==1);
 assert(usb_role_switch_get_role(sw)==USB_ROLE_DEVICE);
 observed=USB_ROLE_HOST;
 assert(role_show(&sw->dev,&dev_attr_role,buf)==5 && !strcmp(buf,"host\n"));
 sw->allow_userspace_observation=false;
 assert(usb_role_switch_is_visible(&sw->dev.kobj,&dev_attr_role.attr,0)==0);
 assert(role_store(&sw->dev,&dev_attr_role,"host",4)==-EACCES && setter_calls==1);
 sw->allow_userspace_control=true;
 assert(usb_role_switch_is_visible(&sw->dev.kobj,&dev_attr_role.attr,0)==0644);
 assert(role_store(&sw->dev,&dev_attr_role,"device",6)==6 && setter_calls==2);
 callback_error=-EIO;
 assert(role_store(&sw->dev,&dev_attr_role,"host",4)==-EIO && setter_calls==3);
 assert(role_store(&sw->dev,&dev_attr_role,"invalid",7)==-EINVAL && setter_calls==3);
 sw->registered=false;
 assert(usb_role_switch_get_role(sw)==USB_ROLE_NONE);
 free(sw);
}
C
} > "$work/boundary.c"
"${CC:-cc}" -std=gnu11 -Wall -Wextra -Werror -Wno-unused-parameter "$work/boundary.c" -o "$work/boundary"
"$work/boundary"
printf 'Actual USB role observation/control boundary passed\n'
