\set ON_ERROR_STOP on
\ir p4-financials.sql

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', 0,
  'scope', 'orders, bookings, coupons, calendar and customer totals'
)) AS p7_financial_summary;
