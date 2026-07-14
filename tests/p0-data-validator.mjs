import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const validator = resolve('admin/scripts/validate-data-fk.cjs');

execFileSync(process.execPath, [validator], { stdio: 'inherit' });

const tempRoot = mkdtempSync(join(tmpdir(), 'yuruicamp-p0-validator-'));
const dataRoot = join(tempRoot, 'data');
try {
  cpSync(resolve('data'), dataRoot, { recursive: true });
  const ordersFile = join(dataRoot, 'commerce', 'orders.json');
  const orders = JSON.parse(readFileSync(ordersFile, 'utf8'));
  const targetId = orders[0].id;
  orders[0].customerId = 'U_DOES_NOT_EXIST';
  writeFileSync(ordersFile, `${JSON.stringify(orders, null, 2)}\n`, 'utf8');

  const result = spawnSync(process.execPath, [validator, '--data-root', dataRoot], { encoding: 'utf8' });
  const output = `${result.stdout}\n${result.stderr}`;
  assert.equal(result.status, 1, 'an invalid FK must return exit code 1');
  assert.match(output, new RegExp(`id=${String(targetId).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`));
  assert.match(output, /field=customerId/);
  assert.match(output, /unknown customer: U_DOES_NOT_EXIST/);
  console.log('P0 validator negative-path test passed');
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}
