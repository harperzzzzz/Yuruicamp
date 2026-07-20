/**
 * Phase 1 假資料遷移腳本
 * - orders: customer_id、items[].productId
 * - customers: shippingAddress
 * - products: description、specifications
 * - reviews: id → REV 前綴、customer_id、productId
 *
 * 執行：node admin/scripts/migrate-phase1-data.cjs
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

/** 中文姓名拆分：第一字為姓 / Split Chinese name — first char = lastName */
function splitChineseName(fullName) {
  var name = String(fullName || '').trim();
  if (!name) {
    return { lastName: '', firstName: '' };
  }
  if (name.length === 1) {
    return { lastName: name, firstName: '' };
  }
  return { lastName: name.charAt(0), firstName: name.slice(1) };
}

/**
 * 解析台灣地址字串（簡化版）
 * Parse Taiwan address string e.g. "台北市信義區松仁路100號"
 */
function parseTaiwanAddress(addressStr) {
  var raw = String(addressStr || '').trim();
  var result = {
    city: '',
    district: '',
    addressLine1: raw
  };
  if (!raw) {
    return result;
  }

  var match = raw.match(/^(.+?(?:市|縣))(.+?(?:區|市|鎮|鄉|島))?(.*)$/);
  if (match) {
    result.city = match[1] || '';
    result.district = match[2] || '';
    result.addressLine1 = (match[3] || '').trim() || raw;
  }
  return result;
}

function emptyShippingAddress() {
  return {
    lastName: '',
    firstName: '',
    postalCode: '',
    city: '',
    district: '',
    township: '',
    addressLine1: '',
    addressLine2: '',
    email: '',
    phone: ''
  };
}

function buildShippingAddress(customer, orderAddress) {
  var parsed = parseTaiwanAddress(orderAddress);
  var names = splitChineseName(customer.name);
  return {
    lastName: names.lastName,
    firstName: names.firstName,
    postalCode: '',
    city: parsed.city,
    district: parsed.district,
    township: '',
    addressLine1: parsed.addressLine1,
    addressLine2: '',
    email: customer.email || '',
    phone: customer.phone || ''
  };
}

function buildProductDescription(product) {
  var spec = product.spec || '標準版';
  var category = product.category || '其他';
  return (
    '<p><strong>' + product.name + '</strong> 為 Yuruicamp 精選的' + category +
    '商品，規格：<em>' + spec + '</em>。</p>' +
    '<p>適合露營、登山與戶外活動使用，後台可透過 Summernote 編輯器調整此描述。</p>'
  );
}

function buildProductSpecifications(product) {
  var specs = {
    '規格': product.spec || '標準版',
    '分類': product.category || '其他'
  };
  if (product.price) {
    specs['售價'] = 'NT$ ' + Number(product.price).toLocaleString();
  }
  if (product.status) {
    specs['狀態'] = product.status === 'active' ? '上架中' : '已停用';
  }
  return specs;
}

function migrateReviewId(oldId) {
  var id = String(oldId || '');
  if (/^R\d+$/.test(id)) {
    return 'REV' + id.slice(1);
  }
  if (/^REV\d+$/.test(id)) {
    return id;
  }
  return id;
}

// ── 載入資料 ──
var customers = readJson('customers.json');
var orders = readJson('orders.json');
var products = readJson('products.json');
var reviews = readJson('reviews.json');

// ── 建立對照表 ──
var orderToCustomer = {};
var customerByName = {};
var orderById = {};
var productByName = {};

customers.forEach(function (c) {
  customerByName[c.name] = c.id;
  (c.orders || []).forEach(function (orderId) {
    orderToCustomer[orderId] = c.id;
  });
});

orders.forEach(function (o) {
  orderById[o.id] = o;
});

products.forEach(function (p) {
  if (p.name) {
    productByName[p.name] = p.id;
  }
});

// ── 1. orders：customer_id + productId ──
var ordersUpdated = 0;
var itemsUpdated = 0;

orders.forEach(function (order) {
  var customerId =
    order.customer_id ||
    orderToCustomer[order.id] ||
    customerByName[order.buyerName] ||
    null;

  if (customerId && order.customer_id !== customerId) {
    order.customer_id = customerId;
    ordersUpdated++;
  } else if (!order.customer_id && customerId) {
    order.customer_id = customerId;
    ordersUpdated++;
  }

  (order.items || []).forEach(function (item) {
    if (!item.productId && item.name && productByName[item.name]) {
      item.productId = productByName[item.name];
      itemsUpdated++;
    }
  });
});

// ── 2. customers：shippingAddress + 同步 orders 清單 ──
var shippingAdded = 0;
var customerOrdersSynced = 0;

// 從 orders 反建每位顧客的訂單清單（以 customer_id 為準）
var ordersByCustomer = {};
orders.forEach(function (order) {
  if (!order.customer_id) {
    return;
  }
  if (!ordersByCustomer[order.customer_id]) {
    ordersByCustomer[order.customer_id] = [];
  }
  if (ordersByCustomer[order.customer_id].indexOf(order.id) === -1) {
    ordersByCustomer[order.customer_id].push(order.id);
  }
});

customers.forEach(function (customer) {
  // shippingAddress
  if (!customer.shippingAddress || !customer.shippingAddress.addressLine1) {
    var sampleOrder = null;
    (customer.orders || []).some(function (orderId) {
      if (orderById[orderId] && orderById[orderId].address) {
        sampleOrder = orderById[orderId];
        return true;
      }
      return false;
    });
    if (!sampleOrder && customer.id && ordersByCustomer[customer.id]) {
      customer.orders = ordersByCustomer[customer.id].slice();
      sampleOrder = customer.orders
        .map(function (oid) { return orderById[oid]; })
        .find(function (o) { return o && o.address; });
    }
    customer.shippingAddress = buildShippingAddress(
      customer,
      sampleOrder ? sampleOrder.address : ''
    );
    shippingAdded++;
  }

  // 同步 orders 陣列（以 orders.json 的 customer_id 為主）
  if (ordersByCustomer[customer.id]) {
    var synced = ordersByCustomer[customer.id].slice().sort();
    var current = (customer.orders || []).slice().sort();
    if (JSON.stringify(synced) !== JSON.stringify(current)) {
      customer.orders = ordersByCustomer[customer.id];
      customerOrdersSynced++;
    }
  }
});

// ── 3. products：description + specifications ──
var productsEnriched = 0;

products.forEach(function (product) {
  var changed = false;
  if (!product.description) {
    product.description = buildProductDescription(product);
    changed = true;
  }
  if (!product.specifications || typeof product.specifications !== 'object') {
    product.specifications = buildProductSpecifications(product);
    changed = true;
  }
  if (changed) {
    productsEnriched++;
  }
});

// ── 4. reviews：REV id、customer_id、productId ──
var reviewsUpdated = 0;

reviews.forEach(function (review) {
  var changed = false;
  var newId = migrateReviewId(review.id);
  if (newId !== review.id) {
    review.id = newId;
    changed = true;
  }
  if (!review.customer_id && review.buyerName && customerByName[review.buyerName]) {
    review.customer_id = customerByName[review.buyerName];
    changed = true;
  }
  if (!review.productId && review.productName && productByName[review.productName]) {
    review.productId = productByName[review.productName];
    changed = true;
  }
  if (changed) {
    reviewsUpdated++;
  }
});

// ── 寫回 ──
writeJson('orders.json', orders);
writeJson('customers.json', customers);
writeJson('products.json', products);
writeJson('reviews.json', reviews);

console.log('Phase 1 migration complete:');
console.log('  orders customer_id updated:', ordersUpdated);
console.log('  order items productId added:', itemsUpdated);
console.log('  customers shippingAddress added:', shippingAdded);
console.log('  customers orders[] synced:', customerOrdersSynced);
console.log('  products enriched:', productsEnriched);
console.log('  reviews updated:', reviewsUpdated);
