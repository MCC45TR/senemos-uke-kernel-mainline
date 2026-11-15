// SPDX-License-Identifier: MIT
// Data-only config preparation and complete, resolved cohort comparisons.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const [mode, profile, work] = process.argv.slice(2);
assert(['seed', 'verify'].includes(mode) && profile && work);
const contract = JSON.parse(fs.readFileSync(path.join(profile, 'manifests/storage-cohort-20261111.json')));
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
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
assert.deepEqual(contract.changes, expected);
assert.deepEqual(contract.profiles.map(row => row.role), ['native', 'cdsp', 'waydroid', 'cdsp-before']);
assert.equal(hash(fs.readFileSync(path.join(profile, contract.fragment))), contract.fragment_sha256);
function parse(text) {
    const values = new Map();
    for (const line of text.split('\n')) {
        const match = line.match(/^(CONFIG_[A-Z0-9_]+)=(.+)$/) || line.match(/^# (CONFIG_[A-Z0-9_]+) is not set$/);
        if (!match) continue;
        assert(!values.has(match[1]), 'Duplicate configuration symbol: ' + match[1]);
        values.set(match[1], match[2] ?? 'n');
    }
    assert(values.size > 1000, 'Incomplete configuration');
    return values;
}
function delta(before, after) {
    return [...new Set([...before.keys(), ...after.keys()])].sort().flatMap(key => {
        const old = before.get(key) ?? 'n', next = after.get(key) ?? 'n';
        return old === next ? [] : [[key, old, next]];
    });
}
const originals = contract.profiles.map(row => {
    const bytes = fs.readFileSync(path.join(profile, row.path));
    assert.equal(hash(bytes), row.sha256, 'Unqualified raw profile: ' + row.role);
    const values = parse(bytes.toString());
    for (const [key, old] of expected) assert.equal(values.get(key) ?? 'n', old, row.role + ': ' + key);
    return bytes.toString();
});
if (mode === 'seed') {
    assert(!fs.existsSync(work), 'Output already exists');
    fs.mkdirSync(work);
    contract.profiles.forEach((row, index) => {
        let candidate = originals[index];
        for (const [key, , value] of expected) {
            const pattern = new RegExp('^(?:' + key + '=.*|# ' + key + ' is not set)$', 'm');
            candidate = pattern.test(candidate) ? candidate.replace(pattern, key + '=' + value) : candidate + key + '=' + value + '\n';
        }
        assert.deepEqual(delta(parse(originals[index]), parse(candidate)), expected);
        const dir = path.join(work, 'seed-' + row.role);
        fs.mkdirSync(dir);
        fs.writeFileSync(path.join(dir, '.config'), candidate, { flag: 'wx' });
    });
    console.log('Storage cohort seeds: four pinned profiles, exactly eight changes each; Kconfig resolution pending.');
} else {
    const records = contract.profiles.map(row => {
        const beforeBytes = fs.readFileSync(path.join(work, 'before-' + row.role, '.config'));
        const afterBytes = fs.readFileSync(path.join(work, 'after-' + row.role, '.config'));
        const before = parse(beforeBytes.toString()), after = parse(afterBytes.toString());
        assert.deepEqual(delta(before, after), expected, 'Unreviewed resolved delta: ' + row.role);
        for (const [key, value] of [
            ['CONFIG_SCSI_UFS_CRYPTO', 'y'], ['CONFIG_QCOM_INLINE_CRYPTO_ENGINE', 'm'],
            ['CONFIG_QCOMTEE', 'm'], ['CONFIG_BLK_DEV_DM', 'm'],
            ['CONFIG_EXT4_FS', 'y'], ['CONFIG_F2FS_FS', 'y'],
            ['CONFIG_MODULE_SIG_FORCE', 'y'], ['CONFIG_SECURITY_SELINUX', 'y'],
        ]) {
            assert.equal(before.get(key), value, row.role + ': retained ' + key);
            assert.equal(after.get(key), value, row.role + ': changed ' + key);
        }
        return { role: row.role, before_sha256: hash(beforeBytes), after_sha256: hash(afterBytes), changes: expected, before, after };
    });
    for (let i = 0; i < records.length; ++i) for (let j = i + 1; j < records.length; ++j) {
        assert.deepEqual(delta(records[i].before, records[j].before), delta(records[i].after, records[j].after),
            'Cohort difference changed: ' + records[i].role + '/' + records[j].role);
    }
    fs.writeFileSync(path.join(work, 'resolved-cohort.json'), JSON.stringify(records.map(({ before, after, ...record }) => record), null, 2) + '\n');
    console.log('Actual storage Kconfig cohort: four complete resolved profiles, eight changes each, six pairwise differences retained.');
}
