import assert from 'node:assert/strict';
import fs from 'node:fs';

const facade = fs.readFileSync(new URL('../storefront/js/api-mock.js', import.meta.url), 'utf8');
const member = fs.readFileSync(
  new URL('../storefront/js/components/member-center.js', import.meta.url),
  'utf8'
);

assert.match(facade, /method: 'PATCH'/);
assert.match(facade, /method: 'DELETE'/);
assert.match(facade, /\/me\/reviews\/\$\{encodeURIComponent\(reviewId\)\}/);
assert.match(member, /查看／修改評論/);
assert.match(member, /existingReview\.comment/);
assert.match(member, /window\.API\.reviews\.update/);
assert.match(member, /window\.API\.reviews\.delete/);
assert.match(member, /確定要刪除這則評論嗎/);
assert.match(member, /form\.dataset\.submitting === 'true'/);
assert.match(member, /setReviewSubmitting\(true\)/);
assert.match(member, /comment: rawComment\.trim\(\) \|\| null/);
assert.match(member, /REVIEW_ALREADY_EXISTS/);
assert.match(member, /REVIEW_ORDER_FORBIDDEN/);
assert.match(member, /REVIEW_ORDER_NOT_COMPLETED/);
assert.match(member, /評價資料格式不正確/);

console.log('Member review management checks passed');
