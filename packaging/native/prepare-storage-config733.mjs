// SPDX-License-Identifier: MIT
// Data-only seed for the independently qualified native92 Kconfig delta.
// Resolution, native objects and complete-profile acceptance remain COPR work.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const [beforePath, fragmentPath, contractPath, output] = process.argv.slice(2);
assert(beforePath && fragmentPath && contractPath && output && process.argv.length === 6);
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
const baseline = '431c839cba7c69f6c8128f67ab180ea3586b6dbc771e532adc13c91bde0e9c33';
const expected = [
    ['CONFIG_BLK_INLINE_ENCRYPTION_FALLBACK', 'n', 'y'],
    ['CONFIG_CRYPTO_ESSIV', 'n', 'm'],
    ['CONFIG_CRYPTO_XTS', 'm', 'y'],
    ['CONFIG_DM_CRYPT', 'n', 'm'],
    ['CONFIG_DM_INLINECRYPT', 'n', 'm'],
    ['CONFIG_FS_ENCRYPTION', 'n', 'y'],
    ['CONFIG_FS_ENCRYPTION_ALGS', 'n', 'y'],
    ['CONFIG_FS_ENCRYPTION_INLINE_CRYPT', 'n', 'y'],
];
function parse(text) {
    const result = new Map();
    for (const line of text.split('\n')) {
        const enabled = line.match(/^(CONFIG_[A-Z0-9_]+)=(.+)$/);
        const disabled = line.match(/^# (CONFIG_[A-Z0-9_]+) is not set$/);
        if (!enabled && !disabled) continue;
        const key = (enabled ?? disabled)[1];
        assert(!result.has(key), 'Duplicate config symbol: ' + key);
        result.set(key, enabled ? enabled[2] : 'n');
    }
    return result;
}
for (const file of [beforePath, fragmentPath, contractPath]) {
    const stat = fs.lstatSync(file);
    assert(stat.isFile() && !stat.isSymbolicLink(), 'Expected a regular source input');
}
const before = fs.readFileSync(beforePath, 'utf8');
const fragment = fs.readFileSync(fragmentPath, 'utf8');
const contract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
assert.equal(contract.schema, 1);
assert.equal(contract.parent_config_sha256, baseline);
assert.equal(hash(before), baseline, 'Unqualified parent configuration');
assert.equal(hash(fragment), contract.fragment_sha256);
assert.equal(contract.native_proof.build, 11303293);
assert.equal(contract.native_proof.source_commit, '7abb0f794df5538759c6bee2608aa1aa5e6a19d7');
assert.equal(contract.native_proof.receipt_sha256, '6ac564ec1795665ad1a839a8d531543a3f9e6e3faef176ba106853bc82d334ac');
assert.deepEqual(contract.changes, expected, 'Unqualified configuration intent');
const old = parse(before);
assert(old.size > 1000, 'Incomplete parent config');
let after = before;
for (const [symbol, prior, next] of expected) {
    assert.equal(old.get(symbol) ?? 'n', prior, 'Wrong parent value: ' + symbol);
    const lines = after.split('\n');
    const matches = lines.flatMap((line, index) =>
        line.startsWith(symbol + '=') || line === '# ' + symbol + ' is not set' ? [index] : []);
    assert(matches.length <= 1);
    if (matches.length) lines[matches[0]] = symbol + '=' + next;
    else lines.splice(lines.length - (lines.at(-1) === '' ? 1 : 0), 0, symbol + '=' + next);
    after = lines.join('\n');
}
const selected = parse(after);
for (const [symbol, value] of parse(fragment)) assert.equal(selected.get(symbol), value);
const actual = [...new Set([...old.keys(), ...selected.keys()])].sort()
    .filter(symbol => (old.get(symbol) ?? 'n') !== (selected.get(symbol) ?? 'n'))
    .map(symbol => [symbol, old.get(symbol) ?? 'n', selected.get(symbol) ?? 'n']);
assert.deepEqual(actual, expected, 'Unrelated configuration changed');
for (const [symbol, value] of [
    ['CONFIG_SCSI_UFS_CRYPTO', 'y'], ['CONFIG_QCOM_INLINE_CRYPTO_ENGINE', 'm'],
    ['CONFIG_QCOMTEE', 'm'], ['CONFIG_MODULE_SIG_FORCE', 'y'],
    ['CONFIG_SECURITY_SELINUX', 'y'], ['CONFIG_EXT4_FS', 'y'], ['CONFIG_F2FS_FS', 'y'],
]) assert.equal(selected.get(symbol), value, 'Retained prerequisite changed: ' + symbol);
assert.equal(hash(after), contract.seed_config_sha256, 'Prepared seed differs from its reviewed bytes');
assert(!fs.existsSync(output), 'Do not overwrite an existing source result');
const temporary = output + '.tmp-' + process.pid;
fs.mkdirSync(temporary, { mode: 0o700 });
try {
    fs.writeFileSync(path.join(temporary, 'native.config'), after, { flag: 'wx', mode: 0o644 });
    fs.writeFileSync(path.join(temporary, 'config-delta.json'), JSON.stringify({
        parent_config_sha256: baseline,
        seed_config_sha256: hash(after),
        changes: actual,
        kconfig_resolved: false,
        native_build_qualified: false,
        encrypted_io_accepted: false,
        volume_or_key_operations: false,
    }, null, 2) + '\n', { flag: 'wx', mode: 0o644 });
    fs.renameSync(temporary, output);
} catch (error) {
    fs.rmSync(temporary, { recursive: true, force: true });
    throw error;
}
console.log('Storage capability seed: exact native92 eight-option delta; no resolution, build, key or volume operation.');
