import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const memberCenterSource = readFileSync(
  new URL('../storefront/js/components/member-center.js', import.meta.url),
  'utf8'
);
const adminOrdersSource = readFileSync(new URL('../admin/js/orders.js', import.meta.url), 'utf8');
const adminOrdersPage = readFileSync(new URL('../admin/partials/orders.html', import.meta.url), 'utf8');

assert.match(
  memberCenterSource,
  /purchase:\s*\[[\s\S]*?\['cancelled', '已取消', 'isCancelled'\][\s\S]*?\],\s*rental:/
);

const cancelledBadgeMatches =
  adminOrdersSource.match(
    /cancelled:\s*'<span class="badge bg-danger(?: order-status-badge)?">已取消<\/span>'/g
  ) || [];
assert.equal(cancelledBadgeMatches.length, 2);
assert(adminOrdersPage.includes('<input type="checkbox" value="cancelled"> 已取消'));

console.log('Product order cancelled status checks passed');
