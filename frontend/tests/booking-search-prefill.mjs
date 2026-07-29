import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const searchSource = await readFile(
  new URL('../booking/js/camp-search.js', import.meta.url),
  'utf8',
);
const detailSource = await readFile(
  new URL('../booking/js/camp-detail.js', import.meta.url),
  'utf8',
);

assert.match(searchSource, /params\.set\('checkIn', searchDateRange\.checkIn\)/);
assert.match(searchSource, /params\.set\('checkOut', searchDateRange\.checkOut\)/);
assert.match(searchSource, /params\.set\('guests', String\(guestCount\)\)/);
assert.match(searchSource, /data-camp-detail-link/);

assert.match(detailSource, /const searchPrefill = readSearchPrefill\(params\)/);
assert.match(detailSource, /picker\.setDate\(\[searchPrefill\.checkIn, searchPrefill\.checkOut\], true\)/);
assert.match(detailSource, /\$\('#guestNum'\)\.val\(searchPrefill\.guests\)/);
assert.match(detailSource, /guests >= 1 && guests <= 30/);
assert.match(detailSource, /isPrefillDateRangeBookable\(searchPrefill\)/);

console.log('booking search-to-detail prefill checks passed');
