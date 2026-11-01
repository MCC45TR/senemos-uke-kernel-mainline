#!/usr/bin/env bash
# Host-only regression using the actual upstream probe/remove bodies.
set -Eeuo pipefail
[[ $# == 1 && -f $1 ]]
source=$(realpath "$1")
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/lifetime.c" <<'C'
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
struct device_node { bool imageon; };
struct device { struct device_node *of_node; };
struct platform_device { struct device dev; };
struct component_ops { int unused; };
struct msm_drm_private { void *dev; void *kms; int (*kms_init)(void *); };
static const struct component_ops a3xx_ops;
static bool separate;
static unsigned gpu_added, gpu_removed, component_added, component_removed;
static bool of_device_is_compatible(struct device_node *node, const char *name) {
    return node->imageon && !strcmp(name, "amd,imageon");
}
static bool msm_gpu_no_components(void) { return separate; }
static int msm_gpu_probe(struct platform_device *device, const struct component_ops *ops) {
    (void)device; assert(ops == &a3xx_ops); ++gpu_added; return 17;
}
static void msm_gpu_remove(struct platform_device *device, const struct component_ops *ops) {
    (void)device; assert(ops == &a3xx_ops); ++gpu_removed;
}
static int component_add(struct device *device, const struct component_ops *ops) {
    (void)device; assert(ops == &a3xx_ops); ++component_added; return 19;
}
static void component_del(struct device *device, const struct component_ops *ops) {
    (void)device; assert(ops == &a3xx_ops); ++component_removed;
}
C
perl -0777 -ne 'for $name ("probe", "remove") { /(static (?:int|void) adreno_$name\(.*?^\})/ms or die "Missing lifecycle body\n"; print "$1\n"; }' "$source" >> "$fixture/lifetime.c"
cat >> "$fixture/lifetime.c" <<'C'
int main(void) {
    for (unsigned mode = 0; mode < 4; ++mode) {
        struct device_node node = { .imageon = !!(mode & 1) };
        struct platform_device device = { .dev.of_node = &node };
        separate = !!(mode & 2);
        gpu_added = gpu_removed = component_added = component_removed = 0;
        int result = adreno_probe(&device);
        adreno_remove(&device);
        assert((gpu_added == 1 && gpu_removed == 1 && !component_added &&
                !component_removed && result == 17) ||
               (component_added == 1 && component_removed == 1 && !gpu_added &&
                !gpu_removed && result == 19));
    }
}
C
${CC:-cc} -std=gnu11 -O2 -Wall -Wextra -Werror "$fixture/lifetime.c" -o "$fixture/lifetime"
"$fixture/lifetime"
echo 'GPU/component and Imageon registration/removal pairs passed without private data'
