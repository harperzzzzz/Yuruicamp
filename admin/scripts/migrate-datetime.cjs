/**
 * 假資料時間精度遷移
 * - movement.json: date → created_at（YYYY-MM-DD HH:mm:ss）
 * - reviews.json: createdAt / replyAt 補秒
 * - ../../data/orders.json: createdAt / deliveredAt 補 datetime
 *
 * 執行：node admin/scripts/migrate-datetime.cjs
 */

const fs = require('fs');
const path = require('path');

const ADMIN_DATA = path.join(__dirname, '../data');
const ROOT_DATA = path.join(__dirname, '../../data');

function readJson(fullPath) {
  return JSON.parse(fs.readFileSync(fullPath, 'utf8'));
}

function writeJson(fullPath, data) {
  fs.writeFileSync(fullPath, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

function pad(n) {
  return String(n).padStart(2, '0');
}

/** 確保 datetime 字串有秒 / Ensure YYYY-MM-DD HH:mm:ss */
function ensureDateTime(value, fallbackTime) {
  var raw = String(value || '').trim();
  if (!raw) {
    return '';
  }
  // 只有日期 YYYY-MM-DD
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    return raw + ' ' + (fallbackTime || '12:00:00');
  }
  // 有日期+時分，缺秒
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(raw)) {
    return raw + ':00';
  }
  return raw;
}

/**
 * 同日多筆依原始順序分配不同時間
 * Spread distinct times for records on the same calendar day.
 */
function buildMovementCreatedAt(dateStr, indexInDay) {
  var baseMinutes = 9 * 60;
  var offset = indexInDay * 47;
  var total = baseMinutes + offset;
  var hours = Math.min(Math.floor(total / 60), 18);
  var mins = total % 60;
  var secs = (indexInDay * 13 + 7) % 60;
  return dateStr + ' ' + pad(hours) + ':' + pad(mins) + ':' + pad(secs);
}

// ── 1. movement.json ──
var movementPath = path.join(ADMIN_DATA, 'movement.json');
var movement = readJson(movementPath);
var dayCounters = {};

var migratedMovement = movement.map(function (record, idx) {
  var dateOnly = String(record.created_at || record.date || '').slice(0, 10);
  if (!dayCounters[dateOnly]) {
    dayCounters[dateOnly] = 0;
  }
  var indexInDay = dayCounters[dateOnly];
  dayCounters[dateOnly] += 1;

  var createdAt;
  if (record.created_at && record.created_at.length > 10) {
    createdAt = ensureDateTime(record.created_at, '09:00:00');
  } else {
    createdAt = buildMovementCreatedAt(dateOnly, indexInDay);
  }

  var next = Object.assign({}, record, { created_at: createdAt });
  delete next.date;
  return next;
});

writeJson(movementPath, migratedMovement);
console.log('movement.json:', migratedMovement.length, 'records → created_at with seconds');
console.log('  sample:', migratedMovement[0].id, migratedMovement[0].created_at);

// ── 2. reviews.json ──
var reviewsPath = path.join(ADMIN_DATA, 'reviews.json');
var reviews = readJson(reviewsPath);
var reviewsUpdated = 0;

reviews.forEach(function (review) {
  var beforeCreated = review.createdAt;
  var beforeReply = review.replyAt;
  review.createdAt = ensureDateTime(review.createdAt, '10:00:00');
  if (review.replyAt) {
    review.replyAt = ensureDateTime(review.replyAt, '14:00:00');
  }
  if (beforeCreated !== review.createdAt || beforeReply !== review.replyAt) {
    reviewsUpdated += 1;
  }
});

writeJson(reviewsPath, reviews);
console.log('reviews.json:', reviewsUpdated, 'records updated with seconds');

// ── 3. 前台 data/orders.json ──
var frontendOrdersPath = path.join(ROOT_DATA, 'orders.json');
if (fs.existsSync(frontendOrdersPath)) {
  var frontendOrders = readJson(frontendOrdersPath);
  var orderTimes = ['10:30:00', '14:20:15', '09:45:33', '16:10:08', '11:55:42'];

  frontendOrders.forEach(function (order, idx) {
    var time = orderTimes[idx % orderTimes.length];
    order.createdAt = ensureDateTime(order.createdAt, time);
    if (order.deliveredAt) {
      order.deliveredAt = ensureDateTime(order.deliveredAt, '15:30:00');
    }
  });

  writeJson(frontendOrdersPath, frontendOrders);
  console.log('data/orders.json:', frontendOrders.length, 'records → datetime with seconds');
} else {
  console.log('data/orders.json: skipped (file not found)');
}

console.log('✓ Datetime migration complete');
