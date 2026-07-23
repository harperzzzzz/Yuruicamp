import assert from 'node:assert/strict';
import fs from 'node:fs';

const apiClient = fs.readFileSync(new URL('../storefront/js/api-client.js', import.meta.url), 'utf8');
const facade = fs.readFileSync(new URL('../storefront/js/api-mock.js', import.meta.url), 'utf8');
const member = fs.readFileSync(
  new URL('../storefront/js/components/member-center.js', import.meta.url),
  'utf8'
);
const detail = fs.readFileSync(
  new URL('../storefront/js/pages/product-detail.js', import.meta.url),
  'utf8'
);

assert.match(apiClient, /typeof FormData !== 'undefined' && body instanceof FormData/);
assert.match(facade, /\/me\/reviews\/photos\?orderItemId=/);
assert.match(facade, /form\.append\('files', file\)/);
assert.match(facade, /photoUrls: Array\.isArray\(payload\.photoUrls\)/);
assert.match(member, /nextTotal > 5/);
assert.match(member, /file\.size > 5 \* 1024 \* 1024/);
assert.match(member, /URL\.revokeObjectURL/);
assert.match(detail, /review\.photos\.filter\(_isSafeReviewPhotoUrl\)/);
assert.match(detail, /圖片載入失敗/);

console.log('Review photo upload checks passed');
