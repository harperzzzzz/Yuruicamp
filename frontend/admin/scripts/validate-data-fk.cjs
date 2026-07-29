/**
 * FK 驗證 — camp-bookings / campgrounds / camp-equipment / variants
 * 含 Zone 超賣與 booking-policy / zone-blocks 檢查
 * 執行：node admin/scripts/validate-data-fk.cjs
 */

const fs = require('fs');
const path = require('path');

const DATA = path.join(__dirname, '../../data');

function readJson(rel) {
  return JSON.parse(fs.readFileSync(path.join(DATA, rel), 'utf8'));
}

function pad2(n) {
  return String(n).padStart(2, '0');
}

function eachStayDate(checkIn, checkOut) {
  const partsIn = checkIn.split('-').map(Number);
  const partsOut = checkOut.split('-').map(Number);
  const start = new Date(partsIn[0], partsIn[1] - 1, partsIn[2]);
  const end = new Date(partsOut[0], partsOut[1] - 1, partsOut[2]);
  if (start >= end) return [];

  const dates = [];
  const cursor = new Date(start.getTime());
  while (cursor < end) {
    dates.push(
      cursor.getFullYear() +
        '-' +
        pad2(cursor.getMonth() + 1) +
        '-' +
        pad2(cursor.getDate())
    );
    cursor.setDate(cursor.getDate() + 1);
  }
  return dates;
}

function addDaysISO(iso, days) {
  const p = iso.split('-').map(Number);
  const d = new Date(p[0], p[1] - 1, p[2]);
  d.setDate(d.getDate() + days);
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

const campgrounds = readJson('catalog/campgrounds.json');
const equipment = readJson('catalog/camp-equipment.json');
const bookings = readJson('commerce/camp-bookings.json');
const orders = readJson('commerce/orders.json');
const products = readJson('catalog/products.json');
const policy = readJson('admin/booking-policy.json');
const blocks = readJson('admin/zone-blocks.json');
const closures = readJson('admin/campground-closures.json');

const cgMap = Object.fromEntries(campgrounds.map((c) => [c.campgroundId, c]));
const zoneMap = {};
campgrounds.forEach((c) => {
  (c.zones || []).forEach((z) => {
    zoneMap[z.zoneId] = Object.assign({}, z, { campgroundId: c.campgroundId });
  });
});
const eqMap = Object.fromEntries(equipment.map((e) => [e.equipmentId, e]));
const productMap = Object.fromEntries(products.map((p) => [p.id, p]));
const errors = [];

const occupyingStatuses = policy.occupyingStatuses || ['pending', 'confirmed', 'completed'];
const windowDays = policy.bookingWindowDays != null ? policy.bookingWindowDays : 90;
const todayISO = (function () {
  const d = new Date();
  return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
})();
const windowEndISO = addDaysISO(todayISO, windowDays);

const listingKeys = new Set();
equipment.forEach((e) => {
  if (!e.variantId) {
    errors.push(`equipment ${e.equipmentId}: missing variantId`);
  }
  if (!e.sku) {
    errors.push(`equipment ${e.equipmentId}: missing sku`);
  }
  const key = `${e.campgroundId}:${e.variantId}`;
  if (listingKeys.has(key)) {
    errors.push(`duplicate listing ${key}`);
  }
  listingKeys.add(key);

  const product = productMap[e.productId];
  if (!product) {
    errors.push(`equipment ${e.equipmentId}: unknown productId ${e.productId}`);
  } else if (e.name !== product.name) {
    errors.push(`equipment ${e.equipmentId}: name "${e.name}" vs product "${product.name}"`);
  }
});

blocks.forEach((blk) => {
  const zone = zoneMap[blk.zoneId];
  if (!zone) {
    errors.push(`zone-block ${blk.id}: unknown zoneId ${blk.zoneId}`);
    return;
  }
  if (blk.campgroundId && blk.campgroundId !== zone.campgroundId) {
    errors.push(`zone-block ${blk.id}: campgroundId mismatch`);
  }
  if (blk.startDate >= blk.endDate) {
    errors.push(`zone-block ${blk.id}: startDate must be before endDate`);
  }
  if ((blk.blockedSites || 0) > zone.totalSites) {
    errors.push(`zone-block ${blk.id}: blockedSites ${blk.blockedSites} > totalSites ${zone.totalSites}`);
  }
});

closures.forEach((cl) => {
  const cg = cgMap[cl.campgroundId];
  if (!cg) {
    errors.push(`closure ${cl.id}: unknown campgroundId ${cl.campgroundId}`);
    return;
  }
  const type = cl.type || 'date_range';
  if (type === 'date_range') {
    if (!cl.startDate || !cl.endDate) {
      errors.push(`closure ${cl.id}: date_range requires startDate/endDate`);
    } else if (cl.startDate >= cl.endDate) {
      errors.push(`closure ${cl.id}: startDate must be before endDate`);
    }
  } else if (type === 'weekly') {
    const dow = Number(cl.dayOfWeek);
    if (Number.isNaN(dow) || dow < 0 || dow > 6) {
      errors.push(`closure ${cl.id}: weekly dayOfWeek must be 0-6`);
    }
    if (!cl.effectiveFrom || !cl.effectiveTo) {
      errors.push(`closure ${cl.id}: weekly requires effectiveFrom/effectiveTo`);
    } else if (cl.effectiveFrom > cl.effectiveTo) {
      errors.push(`closure ${cl.id}: effectiveFrom must be <= effectiveTo`);
    }
  } else {
    errors.push(`closure ${cl.id}: unknown type ${type}`);
  }
});

bookings.forEach((b) => {
  const cgId = b.bookingInfo && b.bookingInfo.campgroundId;
  const cg = cgMap[cgId];
  if (!cg) {
    errors.push(`booking ${b.id}: unknown campgroundId ${cgId}`);
    return;
  }
  if (b.bookingInfo.campgroundName !== cg.name) {
    errors.push(`booking ${b.id}: name mismatch`);
  }
  if (!b.bookingInfo.checkIn || !b.bookingInfo.checkOut) {
    errors.push(`booking ${b.id}: missing checkIn/checkOut`);
  } else if (b.bookingInfo.checkIn >= b.bookingInfo.checkOut) {
    errors.push(`booking ${b.id}: checkIn must be before checkOut`);
  }

  if (b._seedTag === 'booking-window-v1' && b.bookingInfo.checkIn > windowEndISO) {
    // 允許一筆刻意超出窗口的測試單
  } else if (b.bookingInfo.checkIn >= todayISO && b.bookingInfo.checkIn > windowEndISO) {
    errors.push(`booking ${b.id}: checkIn ${b.bookingInfo.checkIn} outside ${windowDays}-day window`);
  }

  (b.selectedZones || []).forEach((z) => {
    if (!(cg.zones || []).some((zone) => zone.zoneId === z.zoneId)) {
      errors.push(`booking ${b.id}: zone ${z.zoneId} not in ${cgId}`);
    }
  });
  (b.selectedRentals || []).forEach((r) => {
    const eq = eqMap[r.equipmentId];
    if (!eq) {
      errors.push(`booking ${b.id}: unknown equipment ${r.equipmentId}`);
      return;
    }
    if (eq.campgroundId !== cgId) {
      errors.push(
        `booking ${b.id}: equipment ${r.equipmentId} at ${eq.campgroundId}, booking at ${cgId}`
      );
    }
    if (r.name !== eq.name) {
      errors.push(`booking ${b.id}: rental name "${r.name}" vs "${eq.name}"`);
    }
    if (r.variantId && r.variantId !== eq.variantId) {
      errors.push(`booking ${b.id}: variantId mismatch for ${r.equipmentId}`);
    }
  });
});

// 超賣檢查：每 zone 每晚 occupied + blocked <= totalSites
const occupancyByNight = {};

bookings.forEach((b) => {
  if (occupyingStatuses.indexOf(b.status) === -1) return;
  const nights = eachStayDate(b.bookingInfo.checkIn, b.bookingInfo.checkOut);
  (b.selectedZones || []).forEach((z) => {
    nights.forEach((dateISO) => {
      const key = z.zoneId + '|' + dateISO;
      occupancyByNight[key] = (occupancyByNight[key] || 0) + (Number(z.quantity) || 0);
    });
  });
});

blocks.forEach((blk) => {
  const nights = eachStayDate(blk.startDate, blk.endDate);
  nights.forEach((dateISO) => {
    const key = blk.zoneId + '|' + dateISO;
    occupancyByNight[key] = occupancyByNight[key] || 0;
    occupancyByNight['block|' + key] = (occupancyByNight['block|' + key] || 0) + (Number(blk.blockedSites) || 0);
  });
});

Object.keys(occupancyByNight).forEach((key) => {
  if (key.indexOf('block|') === 0) return;
  const zoneId = key.split('|')[0];
  const zone = zoneMap[zoneId];
  if (!zone) return;
  const booked = occupancyByNight[key] || 0;
  const blocked = occupancyByNight['block|' + key] || 0;
  if (booked + blocked > zone.totalSites) {
    errors.push(
      `overbooking ${key}: booked ${booked} + blocked ${blocked} > capacity ${zone.totalSites}`
    );
  }
});

// ─── Schema migration checks (P1 / P2 / P4) ───
const customers = readJson('customers/customers.json');
customers.forEach((c) => {
  if (Object.prototype.hasOwnProperty.call(c, 'orders')) {
    errors.push(`customer ${c.id}: still has orders[] (should use orders.customerId FK)`);
  }
  if (Object.prototype.hasOwnProperty.call(c, 'rentals')) {
    errors.push(`customer ${c.id}: still has rentals[] (should use camp-bookings.customerId FK)`);
  }
});

const articles = readJson('marketing/articles.json');
articles.forEach((article) => {
  (article.relatedProducts || []).forEach((pid) => {
    if (/^prod-/i.test(String(pid))) {
      errors.push(`article ${article.id}: relatedProducts still uses legacy id ${pid}`);
    } else if (!productMap[pid]) {
      errors.push(`article ${article.id}: unknown relatedProducts ${pid}`);
    }
  });
  (article.content || []).forEach((block, idx) => {
    if (!block || block.type !== 'product') return;
    const pid = block.productId;
    if (/^prod-/i.test(String(pid))) {
      errors.push(`article ${article.id} content[${idx}]: legacy productId ${pid}`);
    } else if (!productMap[pid]) {
      errors.push(`article ${article.id} content[${idx}]: unknown productId ${pid}`);
    }
  });
});

// rental-skus → camp-equipment.stock 對齊（僅檢查既有 listing）
const rentalSkus = readJson('admin/rental-skus.json');
const stockLookup = new Map();
rentalSkus.forEach((sku) => {
  (sku.variants || []).forEach((variant) => {
    Object.keys(variant.camp || {}).forEach((cgId) => {
      stockLookup.set(
        sku.id + '|' + variant.id + '|' + cgId,
        Number(variant.camp[cgId]) || 0
      );
    });
  });
});
equipment.forEach((listing) => {
  const key =
    listing.rentalSkuId + '|' + listing.variantId + '|' + listing.campgroundId;
  if (!stockLookup.has(key)) {
    errors.push(
      `equipment ${listing.equipmentId}: no matching rental-skus stock key ${key}`
    );
    return;
  }
  const expected = stockLookup.get(key);
  if (listing.stock !== expected) {
    errors.push(
      `equipment ${listing.equipmentId}: stock ${listing.stock} != rental-skus ${expected} (run sync:listings)`
    );
  }
  if (typeof listing.specLabel === 'string' && listing.specLabel.includes('、')) {
    errors.push(`equipment ${listing.equipmentId}: specLabel still uses 、`);
  }
});

// orders / bookings specLabel 不得含頓號
orders.forEach((order) => {
  (order.items || []).forEach((item, idx) => {
    if (typeof item.specLabel === 'string' && item.specLabel.includes('、')) {
      errors.push(`order ${order.id} items[${idx}]: specLabel uses 、`);
    }
  });
});
bookings.forEach((booking) => {
  (booking.selectedRentals || []).forEach((rental, idx) => {
    if (typeof rental.specLabel === 'string' && rental.specLabel.includes('、')) {
      errors.push(`booking ${booking.id} rentals[${idx}]: specLabel uses 、`);
    }
  });
});

// movement 必須 camelCase createdAt
const movements = readJson('admin/movement.json');
movements.forEach((m) => {
  if (Object.prototype.hasOwnProperty.call(m, 'created_at')) {
    errors.push(`movement ${m.id}: still has created_at (use createdAt)`);
  }
  if (!m.createdAt) {
    errors.push(`movement ${m.id}: missing createdAt`);
  }
});

// coupons 必有 category / type / minOrder
const coupons = readJson('promotions/coupons.json');
coupons.forEach((c) => {
  if (!c.category) errors.push(`coupon ${c.code}: missing category`);
  if (!c.type) errors.push(`coupon ${c.code}: missing type`);
  if (c.minOrder == null) errors.push(`coupon ${c.code}: missing minOrder`);
});

if (errors.length) {
  console.error('FK validation FAILED (' + errors.length + '):');
  errors.forEach((e) => console.error(' -', e));
  process.exit(1);
}
console.log(
  'FK validation OK (' +
    bookings.length +
    ' bookings, ' +
    equipment.length +
    ' listings, ' +
    blocks.length +
    ' zone-blocks, ' +
    closures.length +
    ' closures, ' +
    customers.length +
    ' customers, ' +
    articles.length +
    ' articles, ' +
    movements.length +
    ' movements, ' +
    coupons.length +
    ' coupons)'
);
