#!/usr/bin/env node
const { finish, issue, parseArgs, readJson, writeJson } = require('./lib/data-contracts.cjs');

const args = parseArgs(process.argv.slice(2));
const issues = [];
const changedFiles = new Set();
const load = (file) => readJson(args, file);
const save = (file, value) => {
  changedFiles.add(file);
  if (args.write) writeJson(args, file, value);
};

const products = load('catalog/products.json');
let productChanged = false;
for (const product of products) {
  const branch = {};
  for (const variant of product.variants || [])
    for (const [key, value] of Object.entries(variant.branch || {})) branch[key] = (branch[key] || 0) + value;
  const totalStock = Object.values(branch).reduce((sum, value) => sum + value, 0);
  if (JSON.stringify(product.branch || {}) !== JSON.stringify(branch)) {
    if (args.write) product.branch = branch;
    else issues.push(issue('catalog/products.json', product.id, 'branch', 'derived branch totals are stale'));
    productChanged = true;
  }
  if (product.totalStock !== totalStock) {
    if (args.write) product.totalStock = totalStock;
    else
      issues.push(
        issue(
          'catalog/products.json',
          product.id,
          'totalStock',
          `derived value ${product.totalStock}; expected ${totalStock}`
        )
      );
    productChanged = true;
  }
}
if (args.write && productChanged) save('catalog/products.json', products);

const filesWithSpecLabels = [
  ['commerce/orders.json', (row) => row.items || []],
  ['commerce/camp-bookings.json', (row) => row.selectedRentals || []],
];
for (const [file, select] of filesWithSpecLabels) {
  const rows = load(file);
  let changed = false;
  for (const row of rows) {
    for (const [index, item] of select(row).entries()) {
      if (typeof item.specLabel === 'string' && item.specLabel.includes('、')) {
        if (args.write)
          item.specLabel = item.specLabel
            .split('、')
            .map((part) => part.trim())
            .join(' / ');
        else issues.push(issue(file, row.id, `items[${index}].specLabel`, 'use " / " as the separator'));
        changed = true;
      }
    }
  }
  if (args.write && changed) save(file, rows);
}

const coupons = load('promotions/coupons.json');
let couponsChanged = false;
for (const coupon of coupons) {
  for (const [field, fallback] of [
    ['type', 'fixed'],
    ['minOrder', 0],
  ]) {
    if (coupon[field] == null) {
      if (args.write) coupon[field] = fallback;
      else
        issues.push(
          issue('promotions/coupons.json', coupon.code, field, `missing default ${JSON.stringify(fallback)}`)
        );
      couponsChanged = true;
    }
  }
}
if (args.write && couponsChanged) save('promotions/coupons.json', coupons);

const movements = load('admin/movement.json');
let movementsChanged = false;
for (const movement of movements) {
  if (!movement.createdAt && movement.created_at) {
    if (args.write) {
      movement.createdAt = movement.created_at;
      delete movement.created_at;
    } else
      issues.push(
        issue('admin/movement.json', movement.id, 'created_at', 'legacy field must be renamed to createdAt')
      );
    movementsChanged = true;
  }
}
if (args.write && movementsChanged) save('admin/movement.json', movements);

finish(
  issues,
  args.write
    ? `Phase 1 normalization completed (${changedFiles.size} file(s) changed)`
    : 'Phase 1 normalization check passed (0 differences; read-only)'
);
