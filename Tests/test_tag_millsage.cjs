const assert = require('node:assert/strict');
const fs = require('node:fs');

const paths = process.argv.slice(2);
assert.equal(paths.length, 2, 'Pass the iOS and Android catalog paths');
const catalogs = paths.map(path => JSON.parse(fs.readFileSync(path, 'utf8')));
assert.deepEqual(catalogs[0], catalogs[1], 'Both platforms must publish the same catalog');
const catalog = catalogs[0];
const entries = new Map(catalog.entries.map(entry => [entry.id, entry]));
assert.equal(entries.size, catalog.entries.length, 'Entry IDs must be unique');
assert.ok(catalog.changelog.some(change => change.revision === '2026.10.01.1'), 'Keep the millsage release in catalog history');
assert.equal(catalog.changelog[0].revision, catalog.revision);
const expected = [
    ['tag-0474', 'millsage', 'group', 'tag-0030', '#AA22EE', ['#AA22EE', '#99FF99', '#FF4444', '#5555FF', '#77FFFF', '#EE99EE']],
    ['tag-0475', '汐见萤', 'character', 'tag-0474', '#99FF99', ['#AA22EE', '#99FF99']],
    ['tag-0476', '伊泽枣', 'character', 'tag-0474', '#FF4444', ['#AA22EE', '#FF4444']]
];
const normalized = value => value.replace(/\s/g, '').toLowerCase();
for (const [id, name, kind, parentID, solidColor, colors] of expected) {
    const entry = entries.get(id);
    assert.ok(entry, id);
    assert.equal(entry.names.zhHans, name);
    assert.equal(entry.kind, kind);
    assert.equal(entry.parentID, parentID);
    assert.ok(entries.has(parentID));
    assert.equal(entry.solidColor, solidColor);
    assert.deepEqual(entry.colors, colors);
    const categories = catalog.categories.filter(category =>
        category.ranges.some(range => range.start <= id && id <= range.end));
    assert.deepEqual(categories.map(category => category.id), ['ip-bandori'], 'New tags must be browsable under BanG Dream!');
    for (const language of ['zhHans', 'zhHantHK', 'zhHantTW', 'en', 'ja']) {
        assert.ok(entry.names[language]?.trim());
    }
    for (const value of [...Object.values(entry.names), ...entry.aliases]) {
        const matches = catalog.entries.filter(candidate =>
            [...Object.values(candidate.names), ...candidate.aliases].some(alias => normalized(alias) === normalized(value)));
        assert.deepEqual(matches.map(candidate => candidate.id), [id], 'Name/alias must resolve uniquely: ' + value);
    }
}
console.log('PASS: dual-platform identity, official colors, parent links, category coverage and multilingual search aliases');
