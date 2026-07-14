import assert from 'node:assert/strict';
import { validateObservation } from './p7-observation-validator.mjs';

const start = Date.parse('2026-07-18T00:00:00+08:00');
const sampleCount = 7 * 24 * 12 + 1;
const samples = Array.from({ length: sampleCount }, (_, index) => ({
  observedAt: new Date(start + index * 5 * 60 * 1000).toISOString(),
  dayType: index === sampleCount - 1 ? 'holiday' : 'weekday',
  sourceTargetDifference: 0,
  dtoDifference: 0,
  legacyReadCount: 0,
  legacyWriteCount: 0,
  transactionCount: index < 100 ? 1 : 0,
  evidenceReference: `immutable://reconciliation/sample-${index}`,
}));

const approved = {
  phase: 'P7',
  status: 'CONTRACT_APPROVED',
  v700Authorized: true,
  externalObservation: {
    status: 'COMPLETE',
    startedAt: samples[0].observedAt,
    endedAt: samples.at(-1).observedAt,
    approvedGoldenCaseCount: 0,
    fiveMinuteReconciliationSamples: samples.length,
    maximumReconciliationDifference: 0,
    legacyReadCount: 0,
    legacyWriteCount: 0,
    dtoDifferenceCount: 0,
    immutableEvidenceReference: 'immutable://p7/evidence-bundle',
    samples,
    performanceQueries: [{
      seedAtLeastProduction: true,
      thresholdMs: 250,
      executionMs: 25,
      unapprovedSequentialScans: 0,
      evidenceReference: 'immutable://p7/performance/query-1',
    }],
    backupRestore: {
      backupChecksum: 'a'.repeat(64),
      restoredChecksum: 'a'.repeat(64),
      restoredValidationIssues: 0,
      evidenceReference: 'immutable://p7/backup-restore',
    },
    browserSmoke: {
      beforeRestore: { passed: 68, failed: 0 },
      afterRestore: { passed: 68, failed: 0 },
      evidenceReference: 'immutable://p7/browser-smoke',
    },
    approvals: [
      { role: 'business', approver: 'business-owner', approvedAt: samples.at(-1).observedAt, evidenceReference: 'immutable://p7/approval/business' },
      { role: 'operations', approver: 'operations-owner', approvedAt: samples.at(-1).observedAt, evidenceReference: 'immutable://p7/approval/operations' },
    ],
  },
};

assert.deepEqual(validateObservation(approved, {
  requireContract: true, skipRepositoryGuards: true,
}), []);

const waived = {
  phase: 'P7',
  status: 'CONTRACT_WAIVED',
  v700Authorized: true,
  waiver: {
    status: 'APPROVED',
    approvedBy: 'repository-owner',
    approvedAt: '2026-07-14T15:00:00+08:00',
    directive: 'Skip external observation and sign-off and proceed to V700.',
    evidenceReference: 'immutable://p7/waiver/directive',
    scope: [
      'observation-window', 'transaction-volume', 'legacy-telemetry',
      'production-performance', 'deployed-backup-browser',
      'business-operations-signoff',
    ],
  },
  externalObservation: {
    status: 'WAIVED', samples: [], performanceQueries: [], approvals: [],
  },
};
assert.deepEqual(validateObservation(waived, {
  requireWaiver: true, skipRepositoryGuards: true,
}), []);
const invalidWaiver = structuredClone(waived);
invalidWaiver.waiver.scope.pop();
assert(validateObservation(invalidWaiver, {
  requireWaiver: true, skipRepositoryGuards: true,
}).length > 0);

const finalizedWaiver = structuredClone(waived);
finalizedWaiver.finalization = {
  status: 'COMPLETE_WITH_OWNER_WAIVER',
  migrationHead: '700',
  v700: {
    sha256: 'a'.repeat(64),
    authorizationReference: waived.waiver.evidenceReference,
  },
  schemaSnapshot: { sha256: 'b'.repeat(64) },
  databasePaths: { catalogEqual: true, dataEqual: true },
  backupRestore: { exactDataEqual: true },
  regression: { browserSmokeFailed: 0 },
};
assert.deepEqual(validateObservation(finalizedWaiver, {
  requireFinalWaiver: true, skipRepositoryGuards: true,
}), []);
const invalidFinalizedWaiver = structuredClone(finalizedWaiver);
invalidFinalizedWaiver.finalization.databasePaths.catalogEqual = false;
assert(validateObservation(invalidFinalizedWaiver, {
  requireFinalWaiver: true, skipRepositoryGuards: true,
}).length > 0);

for (const mutate of [
  (value) => { value.externalObservation.samples[1].legacyWriteCount = 1; },
  (value) => { value.externalObservation.samples.splice(1, 10); },
  (value) => { value.externalObservation.performanceQueries[0].executionMs = 251; },
  (value) => { value.externalObservation.approvals = []; },
  (value) => { value.externalObservation.backupRestore.restoredChecksum = 'b'.repeat(64); },
]) {
  const invalid = structuredClone(approved);
  mutate(invalid);
  assert(validateObservation(invalid, {
    requireContract: true, skipRepositoryGuards: true,
  }).length > 0);
}

console.log('P7 observation and waiver validator positive and negative cases passed');
