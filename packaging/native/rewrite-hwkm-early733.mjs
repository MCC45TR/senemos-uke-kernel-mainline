// SPDX-License-Identifier: GPL-2.0-only
// Exact full26 recipe extension. Every replaced statement has a whole-file inverse.
import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const [input, output, contract] = process.argv.slice(2);
const m = JSON.parse(fs.readFileSync(contract));
const before = fs.readFileSync(input, 'utf8');
assert.equal(crypto.createHash('sha256').update(before).digest('hex'), m.parent_spec_sha256);
let after = before;
const edits = [];
function once(old, next) {
  assert.equal(after.split(old).length, 2, 'Ambiguous full26 anchor: ' + JSON.stringify(old));
  after = after.replace(old, () => next); edits.push([old, next]);
}
once('%global senemos_build_release 26\n', '%global senemos_build_release 27\n');
once('Source191: uke-ssc-time-reference-delivery.tar.xz\n',
  'Source191: uke-ssc-time-reference-delivery.tar.xz\nSource192: uke-hwkm-early.tar.xz\nSource200: uke-crm-passive.tar.xz\n');
once('Provides: uke-kernel(ssc-time-reference-diagnostic-v1) = 1\n',
  'Provides: uke-kernel(ssc-time-reference-diagnostic-v1) = 1\nProvides: uke-kernel(hwkm-probe-profile-v1) = 1\n');
once('\n%build\n', '\ntar -xJf %{SOURCE192}\n' +
  '(cd hwkm-early; jq -r \'.source_assets[]|.sha256+"  "+.path\' manifests/hwkm-early-20261115.json | sha256sum -c --strict --quiet -)\n' +
  'tar -xJf %{SOURCE200}\n' +
  '(cd crm-passive; jq -r \'.source_assets[]|.sha256+"  "+.path\' manifests/camera-crm-passive-20261114.json | sha256sum -c --strict --quiet -)\n\n%build\n');
const source = 'bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} source\n';
once(source, source + 'bash hwkm-early/packaging/native/prepare-hwkm-early733.sh "$PWD" %{_uke_out} source %{uke_boot_userspace}/base\n' +
  'uke_hwkm_parent=$(bash hwkm-early/packaging/native/hwkm-early-legacy-view733.sh "$PWD")\n');
// The old18-unit source guards are evaluated on their exact full26 source view.
// The output ELF/Image paths always remain the actual cumulative build output.
for (const phase of ['linked', 'sealed']) {
  once('bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} ' + phase + '\n',
    'bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$uke_hwkm_parent" %{_uke_out} ' + phase + '\n');
}
for (const phase of ['check', 'install']) {
  once('bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$PWD" %{_uke_out} ' + phase + ' \'%{buildroot}\'\n',
    'bash native-hardware/packaging/native/prepare-native-hardware-full733.sh "$uke_hwkm_parent" %{_uke_out} ' + phase + ' \'%{buildroot}\'\n');
}
const parent = 'uke_native_parent=$(bash native-hardware/packaging/native/native-hardware-legacy-view733.sh "$PWD")';
assert.equal(after.split(parent).length, 3);
for (let i = 0; i < 2; ++i) {
  // Different following lines make each edit independently invertible.
  const nextLine = i === 0 ? '\nbash native-profile/packaging/native/prepare-storage-config-full733.sh' : '\ninstall -Dm644';
  once(parent + nextLine,
    'uke_native_parent=$(bash native-hardware/packaging/native/native-hardware-legacy-view733.sh "$uke_hwkm_parent")' + nextLine);
}
for (const phase of ['check', 'install']) {
  once('\n%' + phase + '\n', '\n%' + phase + '\nuke_hwkm_parent=$(bash hwkm-early/packaging/native/hwkm-early-legacy-view733.sh "$PWD")\n');
}
for (const phase of ['linked', 'sealed']) {
  const line = 'bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} ' + phase + '\n';
  once(line, line + 'bash hwkm-early/packaging/native/prepare-hwkm-early733.sh "$PWD" %{_uke_out} ' + phase + '\n');
}
for (const phase of ['install', 'check']) {
  const line = 'bash ssc-time-reference-full/packaging/native/prepare-ssc-time-reference-full733.sh "$PWD" %{_uke_out} ' + phase + ' \'%{buildroot}\'\n';
  once(line, line + 'bash hwkm-early/packaging/native/prepare-hwkm-early733.sh "$PWD" %{_uke_out} ' + phase + ' \'%{buildroot}\'\n');
}
once('%changelog\n', '%changelog\n* Sun Nov 15 2026 Uke contributors - 7.3.3-27\n' +
  '- Embed first-probe HWKM opt-in and retain qualified passive camera clocks.\n' +
  '- Preserve cumulative full26 features, source checks, signed modules and recovery.\n' +
  '- Keep hardware key, secure-boot, encrypted I/O and resume acceptance separate.\n\n');
let inverse = after;
for (const [old, next] of edits.toReversed()) {
  assert.equal(inverse.split(next).length, 2, 'Ambiguous inverse');
  inverse = inverse.replace(next, () => old);
}
assert.equal(inverse, before, 'Unrelated full26 recipe changed');
for (const section of ['prep', 'build', 'check', 'install', 'changelog'])
  assert.equal((after.match(new RegExp('^%' + section + '$', 'mg')) || []).length, 1);
fs.writeFileSync(output, after);
console.log('Full27 recipe whole-file inverse passed; all full26 statements retained with explicit source-view routing.');
