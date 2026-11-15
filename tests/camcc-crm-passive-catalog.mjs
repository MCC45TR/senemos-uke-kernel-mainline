// SPDX-License-Identifier: GPL-2.0-only
// Compare the exact donor's declarations, not an adjacent native catalog.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [oemPath, candidatePath, output] = process.argv.slice(2);
const oem = fs.readFileSync(oemPath, 'utf8'), candidate = fs.readFileSync(candidatePath, 'utf8');
const oracle = [];
for (const m of oem.matchAll(/static struct (clk_\w+) (cam_cc_\w+) = \{([\s\S]*?)\n\};/g)) {
  const op = m[3].match(/\.ops = &(\w+)/);
  if (!op || !/crm/.test(op[1]) || m[1] === 'clk_rcg2') continue;
  const kind = {clk_alpha_pll: 0, clk_alpha_pll_postdiv: 1, clk_branch: 2}[m[1]];
  assert.notEqual(kind, undefined);
  const offset = m[3].match(/\.(?:offset|halt_reg) = (0x[\da-f]+)/)[1];
  oracle.push({name: m[2], type: m[1], kind, offset});
}
assert.equal(oracle.length, 30);
assert.deepEqual([0, 1, 2].map(k => oracle.filter(x => x.kind === k).length), [5, 5, 20]);
const actual = [...candidate.matchAll(/\{ &(cam_cc_\w+)\.clkr, CAM_CC_CRM_(PLL|DIVIDER|BRANCH), (0x[\da-f]+) \}/g)]
  .map(m => ({name: m[1], kind: {PLL: 0, DIVIDER: 1, BRANCH: 2}[m[2]], offset: m[3]}));
assert.deepEqual(actual, oracle.map(({name, kind, offset}) => ({name, kind, offset})));
let generated = oracle.map(x => `static struct ${x.type} ${x.name};`).join('\n') + '\n';
generated += 'static const struct {struct clk_regmap *clock; const struct clk_ops *ops; unsigned kind, offset;} oracle[] = {\n';
const ops = ['clk_alpha_pll_lucid_evo_ops', 'clk_alpha_pll_postdiv_lucid_ole_ops', 'clk_branch2_ops'];
generated += oracle.map(x => `{ &${x.name}.clkr, &${ops[x.kind]}, ${x.kind}, ${x.offset} },`).join('\n') + '\n};\n';
generated += 'static void reset_catalog(void) {\n';
for (const x of oracle) {
  generated += `memset(&${x.name}, 0, sizeof(${x.name}));\n`;
  if (x.kind === 0) generated += `${x.name}.offset=${x.offset}; ${x.name}.regs=regs;\n`;
  if (x.kind === 1) generated += `${x.name}.offset=${x.offset}; ${x.name}.regs=regs; ${x.name}.post_div_shift=10; ${x.name}.width=4; ${x.name}.num_post_div=2; ${x.name}.post_div_table=div_table;\n`;
  if (x.kind === 2) generated += `${x.name}.halt_reg=${x.offset}; ${x.name}.clkr.enable_reg=${x.offset}; ${x.name}.clkr.enable_mask=1;\n`;
}
generated += '}\n';
fs.writeFileSync(output, generated);
console.log('Exact GPL Uke OEM passive catalog: PLL3..7, five even dividers and20 branches match all30 objects');
