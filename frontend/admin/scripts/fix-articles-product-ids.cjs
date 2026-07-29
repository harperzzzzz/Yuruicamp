#!/usr/bin/env node
const { buildCatalog, finish, issue, parseArgs, readJson, writeJson } = require('./lib/data-contracts.cjs');

const args = parseArgs(process.argv.slice(2));
const catalog = buildCatalog(args);
const articles = readJson(args, 'marketing/articles.json');
const issues = [];
let changed = 0;

function normalized(value) {
  const match = /^prod-(\d+)$/i.exec(String(value));
  return match ? `P${match[1].padStart(3, '0')}` : value;
}

function inspect(article, field, holder, key) {
  const before = holder[key];
  const after = normalized(before);
  if (before !== after && args.write && catalog.productById.has(after)) {
    holder[key] = after;
    changed += 1;
  } else if (!catalog.productById.has(after)) {
    issues.push(issue('marketing/articles.json', article.id, field, `unknown product: ${before}`));
  } else if (before !== after) {
    issues.push(
      issue('marketing/articles.json', article.id, field, `legacy ID ${before}; expected ${after}`)
    );
  }
}

for (const article of articles) {
  for (let i = 0; i < (article.relatedProducts || []).length; i += 1)
    inspect(article, `relatedProducts[${i}]`, article.relatedProducts, i);
  for (let i = 0; i < (article.content || []).length; i += 1)
    if (article.content[i].productId)
      inspect(article, `content[${i}].productId`, article.content[i], 'productId');
}

if (args.write && !issues.length && changed) writeJson(args, 'marketing/articles.json', articles);
finish(
  issues,
  args.write
    ? `Article product ID normalization completed (${changed} changed)`
    : 'Article product ID check passed (0 differences; read-only)'
);
