#!/usr/bin/env node
const {
  buildCatalog,
  expectedListingStock,
  finish,
  issue,
  parseArgs,
  writeJson,
} = require('./lib/data-contracts.cjs');

const args = parseArgs(process.argv.slice(2));
const catalog = buildCatalog(args);
const issues = [];
let changed = 0;

for (const listing of catalog.listings) {
  const expected = expectedListingStock(catalog, listing);
  if (expected == null) {
    issues.push(
      issue(
        'catalog/camp-equipment.json',
        listing.equipmentId,
        'stock',
        'authoritative rental stock entry is missing'
      )
    );
  } else if (listing.stock !== expected) {
    if (args.write) {
      listing.stock = expected;
      changed += 1;
    } else {
      issues.push(
        issue(
          'catalog/camp-equipment.json',
          listing.equipmentId,
          'stock',
          `derived value ${listing.stock}; expected ${expected}`
        )
      );
    }
  }
}

if (args.write && !issues.length && changed) writeJson(args, 'catalog/camp-equipment.json', catalog.listings);
finish(
  issues,
  args.write
    ? `Rental listing sync completed (${changed} changed)`
    : 'Rental listing check passed (0 differences; read-only)'
);
