const fs = require('node:fs');
const path = require('node:path');

function parseArgs(argv) {
  const args = { write: false, dataRoot: path.resolve('data') };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--write') args.write = true;
    else if (argv[i] === '--data-root') args.dataRoot = path.resolve(argv[++i]);
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return args;
}

function dataFile(args, relativePath) {
  return path.join(args.dataRoot, ...relativePath.split('/'));
}

function readJson(args, relativePath) {
  const file = dataFile(args, relativePath);
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    error.message = `${relativePath}: ${error.message}`;
    throw error;
  }
}

function writeJson(args, relativePath, value) {
  if (!args.write) throw new Error('Refusing to write without --write');
  fs.writeFileSync(dataFile(args, relativePath), `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function issue(file, id, field, reason) {
  return { file: `data/${file}`, id: String(id ?? '<root>'), field, reason };
}

function printIssues(issues) {
  for (const item of issues) {
    console.error(`[ERROR] ${item.file} id=${item.id} field=${item.field}: ${item.reason}`);
  }
  console.error(`Validation failed: ${issues.length} error(s)`);
}

function finish(issues, successMessage) {
  if (issues.length) {
    printIssues(issues);
    process.exitCode = 1;
    return false;
  }
  console.log(successMessage);
  return true;
}

function addDuplicateIssues(rows, key, file, issues, parent = '') {
  const seen = new Set();
  for (const row of rows) {
    const value = row?.[key];
    const id = parent ? `${parent}/${value ?? '<missing>'}` : value;
    if (value == null || value === '') issues.push(issue(file, id, key, 'required value is missing'));
    else if (seen.has(value)) issues.push(issue(file, id, key, `duplicate value ${value}`));
    else seen.add(value);
  }
}

function buildCatalog(args) {
  const products = readJson(args, 'catalog/products.json');
  const campgrounds = readJson(args, 'catalog/campgrounds.json');
  const rentals = readJson(args, 'admin/rental-skus.json');
  const customers = readJson(args, 'customers/customers.json');
  const orders = readJson(args, 'commerce/orders.json');
  const listings = readJson(args, 'catalog/camp-equipment.json');

  return {
    products,
    campgrounds,
    rentals,
    customers,
    orders,
    listings,
    productById: new Map(products.map((row) => [row.id, row])),
    variantById: new Map(
      products.flatMap((product) =>
        (product.variants || []).map((variant) => [variant.id, { ...variant, productId: product.id }])
      )
    ),
    campgroundById: new Map(campgrounds.map((row) => [row.campgroundId, row])),
    zoneById: new Map(
      campgrounds.flatMap((campground) =>
        (campground.zones || []).map((zone) => [
          zone.zoneId,
          { ...zone, campgroundId: campground.campgroundId },
        ])
      )
    ),
    rentalById: new Map(rentals.map((row) => [row.id, row])),
    customerById: new Map(customers.map((row) => [row.id, row])),
    orderById: new Map(orders.map((row) => [String(row.id), row])),
    listingById: new Map(listings.map((row) => [row.equipmentId, row])),
  };
}

function expectedListingStock(catalog, listing) {
  const rental = catalog.rentalById.get(listing.rentalSkuId);
  const variant = rental?.variants?.find((item) => item.id === listing.variantId);
  return variant?.camp?.[listing.campgroundId];
}

module.exports = {
  addDuplicateIssues,
  buildCatalog,
  expectedListingStock,
  finish,
  issue,
  parseArgs,
  readJson,
  writeJson,
};
