\set ON_ERROR_STOP on

-- 開發 seed 唯一入口；片段不可自行開啟或提交交易。
BEGIN;

\ir dev/010-reference.sql
\ir dev/030-catalog.sql
\ir dev/040-inventory.sql

COMMIT;
