import { readFileSync } from 'node:fs';

const read = (file) => readFileSync(new URL(`../${file}`, import.meta.url), 'utf8');
const failures = [];
const expect = (condition, message) => { if (!condition) failures.push(message); };

const adminApi = read('admin/js/admin-api.js');
const movement = read('admin/js/movement.js');
const reviewsAdmin = read('admin/js/reviews.js');
const apiMock = read('js/api-mock.js');
const member = read('js/components/member-center.js');
const blogDetail = read('js/pages/blog-detail.js');
const p6Migration = read('backend/src/main/resources/db/migration/V620__p6_add_review_article_constraints.sql');

expect(adminApi.includes("request('GET', '/inventory-movements')"),
  'admin movement list is not using the normalized inventory-movements API');
expect(!adminApi.includes("request('GET', '/movement')"),
  'admin API still reads the legacy movement endpoint');
expect(movement.includes('inventory_movement_items_view'),
  'movement consumer does not document the P5 view contract');
expect(!movement.includes('item.productId'),
  'movement consumer still depends on a productId-only item identity');
expect(movement.includes('item.variantId') && movement.includes('item.inventoryDomain'),
  'movement consumer lacks variant/domain DTO fields');

expect(!adminApi.includes('saveAll: function (reviews)'),
  'admin review API still exposes legacy bulk writes');
expect(reviewsAdmin.includes('verifiedPurchase === false'),
  'admin reviews do not enforce legacy read-only behavior');
expect(apiMock.includes('const orderItemId = Number(payload.orderItemId)'),
  'review create does not require orderItemId');
expect(!apiMock.includes('customerId: payload.customerId')
  && !apiMock.includes('productId: payload.productId')
  && !apiMock.includes('orderId: payload.orderId'),
  'review create still trusts derivable relationship fields');
expect(member.includes('orderItemId: firstItem && firstItem.orderItemId'),
  'member review form does not send the authoritative orderItemId');

for (const [name, source] of [['admin review consumer', reviewsAdmin], ['review API mock', apiMock]]) {
  expect(!/\b(replyText|replyAt|repliedBy|repliedByName|replyUpdatedAt)\b/.test(source),
    `${name} exposes an official reply contract`);
}

expect(blogDetail.includes("item.type === 'heading'"),
  'blog detail renderer does not support normalized heading blocks');
expect(p6Migration.includes("block_type IN ('text', 'heading')"),
  'P6 article constraint does not allow heading as a text payload');
expect(p6Migration.includes('FROM inventory_movement_items_view item'),
  'P6 movement DTO does not read inventory_movement_items_view');
expect(!p6Migration.includes('CREATE TABLE review_replies'),
  'P6 migration creates the forbidden review_replies table');

if (failures.length) {
  for (const failure of failures) console.error(`[ERROR] ${failure}`);
  throw new Error(`P6 contract validation failed: ${failures.length} issue(s)`);
}

console.log('P6 frontend/API/movement contract validation passed');
