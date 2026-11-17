/* SPDX-License-Identifier: GPL-2.0-only */
/* Board-predicate projection only; this process never accesses hardware. */
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <libfdt.h>
#define ARRAY_SIZE(v) (sizeof(v) / sizeof((v)[0]))
#define UKE_INIT
#include "uke-front-eeprom-dt.h"
static _Alignas(8) unsigned char input[32768], tree[65536], original[32768], repeated[65536];
int main(int argc, char **argv)
{
 assert(argc == 2);
 FILE *f = fopen(argv[1], "rb"); assert(f);
 size_t bytes = fread(input, 1, sizeof(input), f);
 assert(bytes > 40 && bytes < sizeof(input) && !ferror(f) && !fclose(f));
 assert(!fdt_check_full(input, bytes));
 memcpy(original, input, sizeof(input));
 assert(!fdt_open_into(input, tree, sizeof(tree)));
 int ret = uke_front_eeprom_graph(tree);
 if (ret) fprintf(stderr, "Observed front predicates refused: %s (%d)\n", fdt_strerror(ret), ret);
 assert(!ret);
 assert(!memcmp(original, input, sizeof(input)));
 int eeprom = fdt_path_offset(tree, UKE_FRONT_NEW), bus = fdt_path_offset(tree, UKE_FRONT_BUS);
 assert(eeprom >= 0 && bus >= 0);
 assert(!fdt_node_check_compatible(tree, eeprom, "atmel,24c64"));
 assert(fdt_getprop(tree, eeprom, "read-only", NULL));
 assert(uke_front_u32(tree, eeprom, "vcc-microvolt", 1800000));
 assert(uke_front_u32(tree, eeprom, "size", 8192));
 assert(uke_front_u32(tree, eeprom, "address-width", 16));
 assert(!strcmp(fdt_getprop(tree, bus, "status", NULL), "okay"));
 assert(uke_front_disabled(tree, fdt_path_offset(tree, UKE_FRONT_BUS "/qcom,cam-sensor1")));
 memcpy(repeated, tree, sizeof(tree));
 assert(!uke_front_eeprom_graph(tree) && !memcmp(repeated, tree, sizeof(tree)));
 puts("Observed front predicates: unchanged native helper admits remapped board-only projection, immutable input, 8K read-only EEPROM, scoped VCC and disabled sensor; repeat is byte-identical; no hardware access");
 return 0;
}
