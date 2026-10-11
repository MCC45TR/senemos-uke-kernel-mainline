#!/usr/bin/env bash
# Host-only check of the real Cliffs initializer and upstream GPIO predicate.
set -Eeuo pipefail
kernel=${1:?Pass the prepared kernel source directory}
work=$(mktemp -d)
trap 'rm -r -- "$work"' EXIT
{
    cat <<'CPP'
#include <cassert>
#include <cstddef>
#define BIT(n) (1U << (n))
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
CPP
    awk '/^#define PINFUNCTION_FLAG_GPIO/ {print}
         /^struct pinfunction \{/ {emit=1} emit {print} emit && /^};/ {emit=0}
         /^#define PINCTRL_.*PINFUNCTION\(/ {emit_macro=1}
         emit_macro {print} emit_macro && !/\\$/ {emit_macro=0}' "$kernel/include/linux/pinctrl/pinctrl.h"
    awk '/^#define MSM_GPIO_PIN_FUNCTION/ {emit=1} emit {print} emit && !/\\$/ {emit=0}' "$kernel/drivers/pinctrl/qcom/pinctrl-msm.h"
    awk '/^#define FUNCTION\(/ {emit=1} emit {print} emit && !/\\$/ {emit=0}' "$kernel/drivers/pinctrl/qcom/pinctrl-cliffs.c"
    cat <<'CPP'
enum { msm_mux_gpio, msm_mux_HOST2WLAN_SOL };
const char *gpio_groups[] = {"gpio119"};
const char *HOST2WLAN_SOL_groups[] = {"gpio35"};
CPP
    awk '/^static const struct pinfunction cliffs_functions\[\]/ {emit=1} emit {print} emit && /FUNCTION\(HOST2WLAN_SOL\)/ {print "};";exit}' "$kernel/drivers/pinctrl/qcom/pinctrl-cliffs.c"
    cat <<'CPP'
struct function_desc { const pinfunction *func; };
struct pinctrl_dev { int pin_function_tree; };
function_desc desc[2] = {{&cliffs_functions[0]}, {&cliffs_functions[1]}};
function_desc *radix_tree_lookup(int *, unsigned int selector) {
    return selector < 2 ? &desc[selector] : nullptr;
}
CPP
    awk '/^bool pinmux_generic_function_is_gpio\(/ {emit=1} emit {print} emit && /^}/ {exit}' "$kernel/drivers/pinctrl/pinmux.c"
    cat <<'CPP'
int main() {
    pinctrl_dev device{};
    assert(pinmux_generic_function_is_gpio(&device, msm_mux_gpio));
    assert(!pinmux_generic_function_is_gpio(&device, msm_mux_HOST2WLAN_SOL));
    assert(!pinmux_generic_function_is_gpio(&device, 2));
}
CPP
} > "$work/check.cpp"
g++ -std=c++20 -O2 -Wall -Wextra -Werror -Wno-missing-field-initializers "$work/check.cpp" -o "$work/check"
"$work/check"
echo 'Cliffs real GPIO initializer and upstream predicate: GPIO accepted, alternate/missing functions rejected'
