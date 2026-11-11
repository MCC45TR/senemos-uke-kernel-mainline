// SPDX-License-Identifier: MIT
// Complete effective configuration comparison, with exactly eight changes.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const [beforePath, afterPath, contractPath, recordPath] = process.argv.slice(2);
assert(beforePath && afterPath && contractPath && recordPath);
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
assert.deepEqual(JSON.parse(fs.readFileSync(contractPath)).changes, expected);
function parse(file) {
    const values = new Map();
    for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
        const match = line.match(/^(CONFIG_[A-Z0-9_]+)=(.+)$/) || line.match(/^# (CONFIG_[A-Z0-9_]+) is not set$/);
        if (!match) continue;
        assert(!values.has(match[1]), 'Duplicate config symbol: ' + match[1]);
        values.set(match[1], match[2] ?? 'n');
    }
    assert(values.size > 1000, 'Incomplete effective config');
    return values;
}
const before = parse(beforePath), after = parse(afterPath);
const changes = [...new Set([...before.keys(), ...after.keys()])].sort().flatMap(key => {
    const old = before.get(key) ?? 'n', next = after.get(key) ?? 'n';
    return old === next ? [] : [[key, old, next]];
});
assert.deepEqual(changes, expected, 'Unreviewed effective config difference');
for (const [key, value] of [
    ['CONFIG_SCSI_UFS_CRYPTO', 'y'], ['CONFIG_QCOM_INLINE_CRYPTO_ENGINE', 'm'],
    ['CONFIG_QCOMTEE', 'm'], ['CONFIG_MODULE_SIG_FORCE', 'y'],
    ['CONFIG_SECURITY_SELINUX', 'y'], ['CONFIG_EXT4_FS', 'y'], ['CONFIG_F2FS_FS', 'y'],
]) {
    assert.equal(before.get(key), value, 'Missing prerequisite: ' + key);
    assert.equal(after.get(key), value, 'Changed prerequisite: ' + key);
}
fs.writeFileSync(recordPath, JSON.stringify({ exact_changes: changes, all_other_effective_options_retained: true }, null, 2) + '\n');
console.log('Storage full config: exactly eight admitted changes; every other effective setting retained.');
