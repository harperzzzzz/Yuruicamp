\set ON_ERROR_STOP on
\ir p1-business-rules.sql
\ir p2-business-rules.sql
\ir p3-business-rules.sql
\ir p4-business-rules.sql
\ir p5-business-rules.sql
\ir p6-business-rules.sql
\ir p7-business-rules.sql

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', 0,
  'scope', 'P1-P6 positive, negative, rollback and delete-policy cases'
)) AS p7_business_summary;
