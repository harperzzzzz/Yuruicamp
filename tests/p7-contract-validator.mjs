import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const read = (relativePath) => readFileSync(join(root, relativePath), 'utf8');
const hash = (relativePath) => createHash('sha256').update(readFileSync(join(root, relativePath))).digest('hex');
const failures = [];
const assert = (condition, message) => { if (!condition) failures.push(message); };

const properties = read('backend/src/main/resources/application.properties');
assert(
  properties.includes('database.migration.p7.read-new=${DATABASE_MIGRATION_P7_READ_NEW:true}'),
  'P7 normalized-read feature flag or safe default is missing',
);
assert(
  properties.includes('database.migration.p7.write-legacy=${DATABASE_MIGRATION_P7_WRITE_LEGACY:false}'),
  'P7 post-contract legacy-write default is not false',
);

const migrations = readdirSync(join(root, 'backend/src/main/resources/db/migration'));
const v7Migrations = migrations.filter((name) => /^V7\d\d__.*\.sql$/.test(name));
assert(
  v7Migrations.length === 1 && v7Migrations[0] === 'V700__p7_contract_legacy_schema.sql',
  `expected only V700 contract migration, found ${v7Migrations.join(', ')}`,
);

const schemaHash = hash('docs/schema.sql');
assert(
  hash('backend/src/main/resources/db/migration/V001__baseline_current_schema.sql') === schemaHash,
  'V001 no longer matches the frozen P0 schema checksum',
);
assert(hash('docs/schema_copy.sql') !== schemaHash, 'final schema_copy.sql is still the frozen placeholder');
assert(
  read('docs/schema_copy.sql').startsWith('-- Yuruicamp final P7 schema snapshot.'),
  'schema_copy.sql lacks the final generated snapshot header',
);

const evidence = JSON.parse(read('docs/database/p7-observation-evidence.json'));
assert(evidence.status === 'CONTRACT_WAIVED', 'P7 owner waiver status is missing');
assert(evidence.v700Authorized === true, 'V700 is not authorized by the recorded owner waiver');
assert(evidence.externalObservation?.status === 'WAIVED', 'external observation is not explicitly marked WAIVED');
assert(evidence.waiver?.status === 'APPROVED', 'owner waiver decision is not approved');

const v700 = read('backend/src/main/resources/db/migration/V700__p7_contract_legacy_schema.sql');
for (const requiredSql of [
  'ALTER TABLE public.movement_migration_map SET SCHEMA migration',
  'CREATE TRIGGER trg_movement_migration_map_read_only',
  'DROP VIEW public.booking_policy_compatibility',
  'DROP VIEW public.zone_blocks_compatibility',
  'DROP VIEW public.campground_closures_compatibility',
]) {
  assert(v700.includes(requiredSql), `V700 is missing: ${requiredSql}`);
}

const forbiddenConsumerPatterns = [
  /\breview_replies\b/,
  /\bmigration\.p[1-6]_legacy_/,
  /\bmovement_migration_map\b/,
  /\bp5_legacy_movement_items\b/,
];
const consumerFiles = [
  'admin/js/admin-api.js', 'admin/js/movement.js', 'admin/js/reviews.js',
  'js/api-mock.js', 'js/components/member-center.js',
];
for (const file of consumerFiles) {
  const source = read(file);
  for (const pattern of forbiddenConsumerPatterns) {
    assert(!pattern.test(source), `${file} still depends on forbidden legacy contract ${pattern}`);
  }
}

for (const required of [
  'docs/database/validation/validate_schema.sql',
  'docs/database/validation/validate_seed.sql',
  'docs/database/validation/validate_financials.sql',
  'docs/database/validation/validate_inventory.sql',
  'docs/database/validation/validate_contract.sql',
  'docs/database/validation/validate_business.sql',
  'docs/database/p7-cutover-runbook.md',
  'docs/database/p7-gate-audit.json',
  'docs/database/p7-observation-evidence.json',
  'docs/database/p7-waiver-decision.md',
  'docs/database/validation/p7-business-rules.sql',
  'admin/scripts/generate-p7-schema-copy.cjs',
  'tests/p7-observation-validator.mjs',
  'tests/p7-observation-validator-test.mjs',
]) {
  assert(existsSync(join(root, required)), `missing P7 artifact: ${required}`);
}

const auditPath = join(root, 'docs/database/p7-gate-audit.json');
if (existsSync(auditPath)) {
  const audit = JSON.parse(readFileSync(auditPath, 'utf8'));
  assert(audit.entryGate?.status === 'PASS', 'P7 entry gate audit is not PASS');
  assert(audit.contractStatus === 'WAIVED_BY_OWNER', 'audit does not record the owner waiver');
  assert(audit.v700Authorized === true, 'audit does not authorize V700');
  assert(audit.finalStatus === 'COMPLETE', 'P7 final audit is not complete');
}

if (failures.length) {
  console.error(failures.map((failure) => `- ${failure}`).join('\n'));
  process.exit(1);
}
console.log('P7 final static contract validator passed');
