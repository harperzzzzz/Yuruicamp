-- 優惠券主檔先於可能的會員領券資料載入。
-- 本批展示資料沒有可追溯的領券人、領券時間、狀態或對應訂單，因此禁止製造 coupon_claims。
-- claimed_quantity 的 0 只用於全新主檔；既有值不由 upsert 覆寫，日後必須由 coupon_claims Trigger 維護。
INSERT INTO public.coupons (
    id,
    code,
    name,
    discount_type,
    discount_value,
    minimum_amount,
    issue_quantity,
    valid_from,
    valid_until,
    status,
    category,
    claimed_quantity
) OVERRIDING SYSTEM VALUE
VALUES
    (1, 'YURUIKAMP20', '悠露營活動折抵 200', 'fixed', 200.00, 0.00, 50, TIMESTAMPTZ '2026-06-01 00:00:00+08:00', TIMESTAMPTZ '2026-08-31 23:59:00+08:00', 'active', 'promotion', 0),
    (2, 'CAMPFUN50', '露營同樂折抵 50', 'fixed', 50.00, 0.00, 100, TIMESTAMPTZ '2026-06-01 00:00:00+08:00', TIMESTAMPTZ '2026-07-15 23:59:00+08:00', 'active', 'promotion', 0),
    (3, 'SUMMER100', '夏日露營折抵 100', 'fixed', 100.00, 0.00, 80, TIMESTAMPTZ '2026-07-01 00:00:00+08:00', TIMESTAMPTZ '2026-09-30 23:59:00+08:00', 'active', 'promotion', 0),
    (4, 'NEWCAMP300', '新營區開幕折抵 300', 'fixed', 300.00, 0.00, 20, TIMESTAMPTZ '2026-09-01 00:00:00+08:00', TIMESTAMPTZ '2026-10-01 23:59:00+08:00', 'active', 'promotion', 0),
    (5, 'OLDCAMP10', '舊營區活動折抵 100', 'fixed', 100.00, 0.00, 30, TIMESTAMPTZ '2026-01-01 00:00:00+08:00', TIMESTAMPTZ '2026-05-01 23:59:00+08:00', 'disabled', 'promotion', 0),
    (6, 'YURUIHBD', '生日禮折抵 200', 'fixed', 200.00, 500.00, 9999, TIMESTAMPTZ '2026-01-01 00:00:00+08:00', TIMESTAMPTZ '2026-12-31 23:59:00+08:00', 'active', 'birthday', 0),
    (7, 'YRUIFIRST', '首購禮折抵 300', 'fixed', 300.00, 1000.00, 9999, TIMESTAMPTZ '2026-01-01 00:00:00+08:00', TIMESTAMPTZ '2026-12-31 23:59:00+08:00', 'active', 'firstPurchase', 0)
ON CONFLICT (id) DO UPDATE SET
    code = EXCLUDED.code,
    name = EXCLUDED.name,
    discount_type = EXCLUDED.discount_type,
    discount_value = EXCLUDED.discount_value,
    minimum_amount = EXCLUDED.minimum_amount,
    issue_quantity = EXCLUDED.issue_quantity,
    valid_from = EXCLUDED.valid_from,
    valid_until = EXCLUDED.valid_until,
    status = EXCLUDED.status,
    category = EXCLUDED.category,
    updated_at = now();

SELECT setval(
    'public.coupons_id_seq',
    GREATEST((SELECT max(id) FROM public.coupons), 1),
    true
);
