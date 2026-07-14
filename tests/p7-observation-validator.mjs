import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const evidencePath = resolve(root, 'docs/database/p7-observation-evidence.json');
const FIVE_MINUTES_MS = 5 * 60 * 1000;
const MAX_SAMPLE_GAP_MS = 6 * 60 * 1000;
const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

const isNonNegativeInteger = (value) => Number.isInteger(value) && value >= 0;
const isSha256 = (value) => typeof value === 'string' && /^[a-f0-9]{64}$/i.test(value);
const isReference = (value) => typeof value === 'string' && value.trim().length >= 8;
const parseTime = (value) => {
  if (typeof value !== 'string' || !/(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return NaN;
  return Date.parse(value);
};

function push(issues, condition, code, detail) {
  if (!condition) issues.push({ code, detail });
}

export function validateObservation(evidence, options = {}) {
  const requireContract = Boolean(options.requireContract);
  const requireFinalWaiver = Boolean(options.requireFinalWaiver);
  const requireWaiver = Boolean(options.requireWaiver) || requireFinalWaiver;
  const skipRepositoryGuards = Boolean(options.skipRepositoryGuards);
  const repositoryRoot = options.rootDir || root;
  const issues = [];
  const external = evidence?.externalObservation || {};
  const samples = Array.isArray(external.samples) ? external.samples : [];
  const performance = Array.isArray(external.performanceQueries)
    ? external.performanceQueries : [];
  const approvals = Array.isArray(external.approvals) ? external.approvals : [];

  push(issues, evidence?.phase === 'P7', 'phase', 'phase must be P7');
  push(issues, Array.isArray(external.samples), 'samples-shape', 'samples must be an array');
  push(issues, Array.isArray(external.performanceQueries), 'performance-shape', 'performanceQueries must be an array');
  push(issues, Array.isArray(external.approvals), 'approval-shape', 'approvals must be an array');

  if (requireWaiver) {
    const waiver = evidence?.waiver || {};
    const requiredScope = [
      'observation-window', 'transaction-volume', 'legacy-telemetry',
      'production-performance', 'deployed-backup-browser',
      'business-operations-signoff',
    ];
    const scope = new Set(Array.isArray(waiver.scope) ? waiver.scope : []);
    push(issues, evidence?.status === 'CONTRACT_WAIVED',
      'waiver-status', 'status must be CONTRACT_WAIVED');
    push(issues, evidence?.v700Authorized === true,
      'waiver-authorization', 'v700Authorized must be true');
    push(issues, waiver.status === 'APPROVED',
      'waiver-decision', 'waiver.status must be APPROVED');
    push(issues, isReference(waiver.approvedBy),
      'waiver-owner', 'waiver approver is required');
    push(issues, Number.isFinite(parseTime(waiver.approvedAt)),
      'waiver-time', 'waiver approval time must be offset-aware');
    push(issues, isReference(waiver.directive),
      'waiver-directive', 'the explicit owner directive is required');
    push(issues, isReference(waiver.evidenceReference),
      'waiver-reference', 'waiver evidence reference is required');
    for (const item of requiredScope) {
      push(issues, scope.has(item), 'waiver-scope', `waiver scope is missing ${item}`);
    }
    push(issues, external.status === 'WAIVED',
      'waiver-external-state', 'external observation must be marked WAIVED');
    push(issues, samples.length === 0 && performance.length === 0 && approvals.length === 0,
      'waiver-no-fabrication', 'waiver evidence must not contain fabricated deployed samples');

    if (requireFinalWaiver) {
      const finalization = evidence?.finalization || {};
      push(issues, finalization.status === 'COMPLETE_WITH_OWNER_WAIVER',
        'final-waiver-status', 'finalization status must be COMPLETE_WITH_OWNER_WAIVER');
      push(issues, finalization.migrationHead === '700',
        'final-migration-head', 'finalization migration head must be 700');
      push(issues, isSha256(finalization?.v700?.sha256),
        'final-v700-checksum', 'final V700 SHA-256 is required');
      push(issues, finalization?.v700?.authorizationReference === waiver.evidenceReference,
        'final-waiver-reference', 'V700 authorization reference must match the owner waiver');
      push(issues, isSha256(finalization?.schemaSnapshot?.sha256),
        'final-snapshot-checksum', 'final schema snapshot SHA-256 is required');
      push(issues, finalization?.databasePaths?.catalogEqual === true,
        'final-catalog-equivalence', 'A/B/C canonical catalogs must be equal');
      push(issues, finalization?.databasePaths?.dataEqual === true,
        'final-data-equivalence', 'A/B normalized data must be equal');
      push(issues, finalization?.backupRestore?.exactDataEqual === true,
        'final-restore-equivalence', 'backup/restore exact data must be equal');
      push(issues, finalization?.regression?.browserSmokeFailed === 0,
        'final-browser-smoke', 'final browser smoke must have zero failures');
    }

    if (!skipRepositoryGuards) {
      const migrationDir = resolve(repositoryRoot, 'backend/src/main/resources/db/migration');
      const v7Files = existsSync(migrationDir)
        ? readdirSync(migrationDir).filter((name) => /^V7\d\d__.*\.sql$/.test(name)) : [];
      const schema = readFileSync(resolve(repositoryRoot, 'docs/schema.sql'));
      const copy = readFileSync(resolve(repositoryRoot, 'docs/schema_copy.sql'));
      const v001 = readFileSync(resolve(repositoryRoot,
        'backend/src/main/resources/db/migration/V001__baseline_current_schema.sql'));
      const digest = (content) => createHash('sha256').update(content).digest('hex');
      if (requireFinalWaiver) {
        const v700Path = v7Files.length === 1 ? resolve(migrationDir, v7Files[0]) : null;
        push(issues, v7Files.length === 1 && v7Files[0].startsWith('V700__'),
          'final-v700-file', `final repository must contain exactly V700: ${v7Files.join(', ')}`);
        push(issues, v700Path && digest(readFileSync(v700Path)) === evidence.finalization.v700.sha256,
          'final-v700-file-checksum', 'V700 file does not match final evidence');
        push(issues, digest(schema) === digest(v001),
          'frozen-baseline-checksum', 'docs/schema.sql and V001 frozen baseline differ');
        push(issues, digest(copy) === evidence.finalization.schemaSnapshot.sha256,
          'final-snapshot-file-checksum', 'schema_copy does not match final evidence');
        push(issues, digest(copy) !== digest(schema),
          'final-snapshot-still-baseline', 'schema_copy must be the final V700 snapshot');
      } else {
        push(issues, v7Files.length === 0, 'premature-v700',
          `waiver authorization must be validated before V700 exists: ${v7Files.join(', ')}`);
        push(issues, digest(schema) === digest(copy) && digest(schema) === digest(v001),
          'snapshot-guard', 'schema_copy and V001 must still equal the frozen schema before V700');
      }
    }
    return issues;
  }

  if (!requireContract) {
    push(
      issues,
      evidence?.status === 'PENDING_EXTERNAL_EVIDENCE' && evidence?.v700Authorized === false,
      'pre-contract-state',
      'pre-contract evidence must remain pending with v700Authorized=false',
    );
    push(issues, samples.length === 0, 'pre-contract-samples', 'repository fixture must not contain fabricated production samples');
    return issues;
  }

  push(issues, evidence?.status === 'CONTRACT_APPROVED', 'contract-status', 'status must be CONTRACT_APPROVED');
  push(issues, evidence?.v700Authorized === true, 'v700-authorization', 'v700Authorized must be true after approval');
  push(issues, external.status === 'COMPLETE', 'external-status', 'externalObservation.status must be COMPLETE');

  const startedAt = parseTime(external.startedAt);
  const endedAt = parseTime(external.endedAt);
  push(issues, Number.isFinite(startedAt), 'start-time', 'startedAt must be an offset-aware timestamp');
  push(issues, Number.isFinite(endedAt), 'end-time', 'endedAt must be an offset-aware timestamp');
  push(issues, Number.isFinite(startedAt) && Number.isFinite(endedAt) && endedAt - startedAt >= SEVEN_DAYS_MS,
    'observation-duration', 'observation window must be at least seven full days');

  const minimumSampleCount = Math.floor(SEVEN_DAYS_MS / FIVE_MINUTES_MS) + 1;
  push(issues, samples.length >= minimumSampleCount, 'sample-count', `at least ${minimumSampleCount} five-minute samples are required`);
  let previousTime = null;
  let observedTransactions = 0;
  const dayTypes = new Set();
  for (const [index, sample] of samples.entries()) {
    const observedAt = parseTime(sample?.observedAt);
    push(issues, Number.isFinite(observedAt), 'sample-time', `sample ${index} needs an offset-aware timestamp`);
    if (Number.isFinite(observedAt) && previousTime != null) {
      push(issues, observedAt > previousTime, 'sample-order', `sample ${index} is not strictly ordered`);
      push(issues, observedAt - previousTime <= MAX_SAMPLE_GAP_MS, 'sample-gap', `sample ${index} gap exceeds six minutes`);
    }
    if (Number.isFinite(observedAt)) previousTime = observedAt;
    push(issues, sample?.sourceTargetDifference === 0, 'source-target-difference', `sample ${index} is not zero`);
    push(issues, sample?.dtoDifference === 0, 'dto-difference', `sample ${index} is not zero`);
    push(issues, sample?.legacyReadCount === 0, 'legacy-read', `sample ${index} legacy reads are not zero`);
    push(issues, sample?.legacyWriteCount === 0, 'legacy-write', `sample ${index} legacy writes are not zero`);
    push(issues, isNonNegativeInteger(sample?.transactionCount), 'transaction-count', `sample ${index} transactionCount is invalid`);
    if (isNonNegativeInteger(sample?.transactionCount)) observedTransactions += sample.transactionCount;
    if (['weekday', 'holiday'].includes(sample?.dayType)) dayTypes.add(sample.dayType);
    push(issues, isReference(sample?.evidenceReference), 'sample-reference', `sample ${index} lacks immutable evidence reference`);
  }
  if (samples.length && Number.isFinite(startedAt) && Number.isFinite(endedAt)) {
    push(issues, parseTime(samples[0]?.observedAt) <= startedAt + MAX_SAMPLE_GAP_MS,
      'first-sample', 'first sample is not aligned with observation start');
    push(issues, parseTime(samples.at(-1)?.observedAt) >= endedAt - MAX_SAMPLE_GAP_MS,
      'last-sample', 'last sample is not aligned with observation end');
  }
  push(issues, dayTypes.has('weekday') && dayTypes.has('holiday'),
    'day-coverage', 'samples must include weekday and approved holiday coverage');
  push(issues, observedTransactions >= 100 || external.approvedGoldenCaseCount >= 100,
    'transaction-volume', 'at least 100 observed transactions or approved golden cases are required');
  push(issues, external.fiveMinuteReconciliationSamples === samples.length,
    'sample-summary', 'fiveMinuteReconciliationSamples must equal samples.length');
  push(issues, external.maximumReconciliationDifference === 0,
    'reconciliation-summary', 'maximum reconciliation difference must be zero');
  push(issues, external.legacyReadCount === 0 && external.legacyWriteCount === 0,
    'legacy-summary', 'summary legacy read/write counts must both be zero');
  push(issues, external.dtoDifferenceCount === 0, 'dto-summary', 'summary DTO difference must be zero');

  push(issues, performance.length > 0, 'performance-empty', 'production-sized performance evidence is required');
  for (const [index, query] of performance.entries()) {
    push(issues, query?.seedAtLeastProduction === true, 'performance-seed', `query ${index} seed is not production-sized`);
    push(issues, Number.isFinite(query?.thresholdMs) && query.thresholdMs > 0,
      'performance-threshold', `query ${index} threshold is invalid`);
    push(issues, Number.isFinite(query?.executionMs) && query.executionMs <= query.thresholdMs,
      'performance-time', `query ${index} exceeds its threshold`);
    push(issues, query?.unapprovedSequentialScans === 0,
      'performance-scan', `query ${index} has an unapproved sequential scan`);
    push(issues, isReference(query?.evidenceReference), 'performance-reference', `query ${index} lacks evidence reference`);
  }

  const restore = external.backupRestore || {};
  push(issues, isSha256(restore.backupChecksum), 'backup-checksum', 'backup checksum must be SHA-256');
  push(issues, isSha256(restore.restoredChecksum), 'restore-checksum', 'restored checksum must be SHA-256');
  push(issues, restore.backupChecksum === restore.restoredChecksum,
    'restore-equality', 'restored checksum must equal backup checksum');
  push(issues, restore.restoredValidationIssues === 0, 'restore-validation', 'restored validation issues must be zero');
  push(issues, isReference(restore.evidenceReference), 'restore-reference', 'backup/restore evidence reference is required');

  const browser = external.browserSmoke || {};
  for (const stage of ['beforeRestore', 'afterRestore']) {
    push(issues, browser?.[stage]?.passed > 0 && browser?.[stage]?.failed === 0,
      `browser-${stage}`, `${stage} browser smoke must pass with zero failures`);
  }
  push(issues, isReference(browser.evidenceReference), 'browser-reference', 'browser evidence reference is required');

  const approvalRoles = new Set(approvals.filter((approval) =>
    isReference(approval?.approver) && Number.isFinite(parseTime(approval?.approvedAt))
      && isReference(approval?.evidenceReference)).map((approval) => approval.role));
  push(issues, approvalRoles.has('business'), 'business-approval', 'business approval is required');
  push(issues, approvalRoles.has('operations'), 'operations-approval', 'operations approval is required');
  push(issues, isReference(external.immutableEvidenceReference),
    'immutable-reference', 'an immutable evidence bundle reference is required');

  if (!skipRepositoryGuards) {
    const migrationDir = resolve(repositoryRoot, 'backend/src/main/resources/db/migration');
    const v7Files = existsSync(migrationDir)
      ? readdirSync(migrationDir).filter((name) => /^V7\d\d__.*\.sql$/.test(name)) : [];
    push(issues, v7Files.length === 0, 'premature-v700', `strict gate must run before V700 exists: ${v7Files.join(', ')}`);
    const schema = readFileSync(resolve(repositoryRoot, 'docs/schema.sql'));
    const copy = readFileSync(resolve(repositoryRoot, 'docs/schema_copy.sql'));
    const v001 = readFileSync(resolve(repositoryRoot, 'backend/src/main/resources/db/migration/V001__baseline_current_schema.sql'));
    const digest = (content) => createHash('sha256').update(content).digest('hex');
    push(issues, digest(schema) === digest(copy) && digest(schema) === digest(v001),
      'snapshot-guard', 'schema_copy and V001 must still equal the frozen schema before V700');
  }
  return issues;
}

function main() {
  const args = new Set(process.argv.slice(2));
  if (args.size !== 1 || (![...args].every((arg) => [
    '--pre-contract', '--require-contract', '--require-waiver', '--require-final-waiver',
  ].includes(arg)))) {
    throw new Error('Usage: node tests/p7-observation-validator.mjs --pre-contract|--require-contract|--require-waiver|--require-final-waiver');
  }
  const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
  const requireContract = args.has('--require-contract');
  const requireWaiver = args.has('--require-waiver');
  const requireFinalWaiver = args.has('--require-final-waiver');
  const issues = validateObservation(evidence, {
    requireContract, requireWaiver, requireFinalWaiver,
  });
  if (issues.length) {
    console.error(JSON.stringify({ status: 'FAIL', issueCount: issues.length, issues }, null, 2));
    process.exit(1);
  }
  console.log(requireFinalWaiver
    ? 'P7 final owner-waiver evidence passed after V700'
    : requireWaiver
    ? 'P7 owner waiver passed; V700 may be authored without fabricated observation evidence'
    : requireContract
      ? 'P7 external observation contract passed; V700 may be authored but has not run'
      : 'P7 pre-contract observation fixture passed; external evidence remains pending');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
