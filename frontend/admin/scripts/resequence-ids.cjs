/**
 * 假資料編號重編腳本（模擬 DB AUTO_INCREMENT PK）
 * Resequence mock data ids to numeric PKs ordered by time.
 *
 * - orders.json     → id: 1, 2, 3…（依 createdAt）
 * - bookings.json   → id: 1, 2, 3…（依 submitted_at）
 * - movement.json   → id: 1, 2, 3…（依 created_at，同日保留原順序）
 * - customers.json  → orders[] / rentals[] 同步改為數字外鍵
 *
 * 執行：node admin/scripts/resequence-ids.cjs
 */

const fs = require('fs');
const path = require('path');

const DATA_DIR = path.join(__dirname, '../data');

function readJson(file) {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, file), 'utf8'));
}

function writeJson(file, data) {
  fs.writeFileSync(
    path.join(DATA_DIR, file),
    JSON.stringify(data, null, 2) + '\n',
    'utf8'
  );
}

/** 正規化舊 id 字串，方便當 map key / Normalize legacy id for map keys */
function normalizeLegacyId(id) {
  if (id === null || id === undefined) {
    return '';
  }
  return String(id).trim();
}

/**
 * 依時間排序並重新編號（純數字 id）
 * Sort by time and assign sequential numeric ids.
 */
function resequenceByTime(records, timeKey) {
  const indexed = records.map((r, i) => ({ r, i }));

  indexed.sort((a, b) => {
    const ta = String(a.r[timeKey] || '');
    const tb = String(b.r[timeKey] || '');
    if (ta !== tb) {
      return ta.localeCompare(tb);
    }
    return a.i - b.i;
  });

  const idMap = {};
  const resequenced = indexed.map(({ r }, idx) => {
    const oldId = normalizeLegacyId(r.id);
    const newId = idx + 1;
    idMap[oldId] = newId;
    return { ...r, id: newId };
  });

  return { records: resequenced, idMap };
}

/** 將 customers 的 orders[] / rentals[] 改為新數字 id */
function remapCustomerRefs(customers, orderMap, bookingMap) {
  return customers.map((c) => ({
    ...c,
    orders: (c.orders || []).map((id) => {
      const key = normalizeLegacyId(id);
      return orderMap[key] !== undefined ? orderMap[key] : id;
    }),
    rentals: (c.rentals || []).map((id) => {
      const key = normalizeLegacyId(id);
      return bookingMap[key] !== undefined ? bookingMap[key] : id;
    })
  }));
}

/** 檢查 id 是否為 1..N 連續整數 */
function validateSequentialIds(records, label) {
  const ids = records.map((r) => r.id).sort((a, b) => a - b);
  const issues = [];

  ids.forEach((id, idx) => {
    const expected = idx + 1;
    if (id !== expected) {
      issues.push({ expected, actual: id, index: idx });
    }
  });

  if (typeof ids[0] !== 'number') {
    issues.push({ error: label + ' id is not numeric', sample: ids[0] });
  }

  return { ok: issues.length === 0, count: ids.length, issues };
}

/** 檢查 customers 外鍵引用是否都存在 */
function validateCustomerRefs(customers, orderIds, bookingIds) {
  const orderSet = new Set(orderIds);
  const bookingSet = new Set(bookingIds);
  const broken = [];

  customers.forEach((c) => {
    (c.orders || []).forEach((id) => {
      if (!orderSet.has(id)) {
        broken.push({ customer: c.id, type: 'order', ref: id });
      }
    });
    (c.rentals || []).forEach((id) => {
      if (!bookingSet.has(id)) {
        broken.push({ customer: c.id, type: 'rental', ref: id });
      }
    });
  });

  return { ok: broken.length === 0, broken };
}

// ── 1. orders ──
const ordersRaw = readJson('orders.json');
const { records: orders, idMap: orderMap } = resequenceByTime(ordersRaw, 'createdAt');

// ── 2. bookings ──
const bookingsRaw = readJson('bookings.json');
const { records: bookings, idMap: bookingMap } = resequenceByTime(bookingsRaw, 'submitted_at');

// ── 3. movement ──
const movementRaw = readJson('movement.json');
const { records: movement, idMap: movementMap } = resequenceByTime(movementRaw, 'created_at');

// ── 4. customers 交叉引用 ──
const customers = remapCustomerRefs(
  readJson('customers.json'),
  orderMap,
  bookingMap
);

// ── 5. 驗證 ──
const orderCheck = validateSequentialIds(orders, 'orders');
const bookingCheck = validateSequentialIds(bookings, 'bookings');
const movementCheck = validateSequentialIds(movement, 'movement');
const refCheck = validateCustomerRefs(
  customers,
  orders.map((o) => o.id),
  bookings.map((b) => b.id)
);

const allOk =
  orderCheck.ok &&
  bookingCheck.ok &&
  movementCheck.ok &&
  refCheck.ok;

if (!allOk) {
  console.error('Validation failed — files NOT written.');
  if (!orderCheck.ok) console.error('  orders:', orderCheck.issues.slice(0, 3));
  if (!bookingCheck.ok) console.error('  bookings:', bookingCheck.issues.slice(0, 3));
  if (!movementCheck.ok) console.error('  movement:', movementCheck.issues.slice(0, 3));
  if (!refCheck.ok) console.error('  customer refs:', refCheck.broken.slice(0, 5));
  process.exit(1);
}

// ── 6. 寫回 ──
writeJson('orders.json', orders);
writeJson('bookings.json', bookings);
writeJson('movement.json', movement);
writeJson('customers.json', customers);

console.log('Resequence complete:');
console.log('  orders:   ', orders.length, 'records → id 1 ~', orders.length);
console.log('  bookings: ', bookings.length, 'records → id 1 ~', bookings.length);
console.log('  movement: ', movement.length, 'records → id 1 ~', movement.length);
console.log('  customers: orders[] / rentals[] remapped to numeric FK');
console.log('');
console.log('Sample remaps (old → new):');
Object.entries(orderMap).slice(0, 3).forEach(([oldId, newId]) => {
  console.log('  order   ', oldId, '→', newId);
});
Object.entries(bookingMap).slice(0, 3).forEach(([oldId, newId]) => {
  console.log('  booking ', oldId, '→', newId);
});
Object.entries(movementMap).slice(0, 3).forEach(([oldId, newId]) => {
  console.log('  movement', oldId, '→', newId);
});
console.log('');
console.log('Earliest records after resequence:');
console.log('  order   id=', orders[0].id, 'createdAt=', orders[0].createdAt);
console.log('  booking id=', bookings[0].id, 'submitted_at=', bookings[0].submitted_at);
console.log('  movement id=', movement[0].id, 'created_at=', movement[0].created_at);
console.log('✓ All validations passed');
