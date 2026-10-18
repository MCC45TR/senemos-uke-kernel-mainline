#!/usr/bin/env bash
# Execute the serial bind policy and upstream descriptor encoder on the host.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
cat <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
typedef uint8_t u8;
#define USB_CONFIG_ATT_SELFPOWER 0x40
#define min(a,b) ((a)<(b)?(a):(b))
#define min_t(t,a,b) min((t)(a),(t)(b))
enum usb_device_speed { USB_SPEED_FULL, USB_SPEED_HIGH, USB_SPEED_SUPER };
struct usb_configuration { unsigned int MaxPower, bmAttributes; };
static bool uke;
static bool of_machine_is_compatible(const char *name) {
 assert(!strcmp(name,"xiaomi,uke")); return uke;
}
C
awk '/^static struct usb_configuration serial_config_driver =/ {emit=1}
     emit {print} emit && /^};/ {exit}' \
    "$kernel/drivers/usb/gadget/legacy/serial.c"
cat <<'C'
static void bind_power_policy(void) {
C
awk '/^static int gs_bind\(/ {bind=1}
     bind && /if \(of_machine_is_compatible\("xiaomi,uke"\)\)/ {emit=1}
     emit {print} emit && /^\t}/ {exit}' \
    "$kernel/drivers/usb/gadget/legacy/serial.c"
cat <<'C'
}
C
awk '/^static u8 encode_bMaxPower\(/ {emit=1}
     emit {print} emit && /^}/ {exit}' "$kernel/drivers/usb/gadget/composite.c"
cat <<'C'
int main(void) {
 struct usb_configuration *c=&serial_config_driver;
 assert(c->MaxPower==0 && c->bmAttributes==USB_CONFIG_ATT_SELFPOWER);
 uke=false; bind_power_policy();
 assert(c->MaxPower==0 && encode_bMaxPower(USB_SPEED_HIGH,c)==0);
 uke=true; bind_power_policy();
 unsigned int expected=min((unsigned int)CONFIG_USB_GADGET_VBUS_DRAW,500U);
 assert(c->MaxPower==expected && c->bmAttributes==USB_CONFIG_ATT_SELFPOWER);
 assert(2U*encode_bMaxPower(USB_SPEED_FULL,c)==expected);
 assert(2U*encode_bMaxPower(USB_SPEED_HIGH,c)==expected);
 assert(8U*encode_bMaxPower(USB_SPEED_SUPER,c)<=expected);
 return 0;
}
C
} > "$work/check.c"
for budget in 100 500 900; do
    "${CC:-cc}" -std=gnu11 -O2 -Wall -Wextra -Werror \
        -DCONFIG_USB_GADGET_VBUS_DRAW="$budget" "$work/check.c" -o "$work/check"
    "$work/check"
done
echo 'Serial power: Uke USB2 cap, descriptor encoding and unchanged foreign self-powered default passed; host enumeration and net charging remain physical tests'
