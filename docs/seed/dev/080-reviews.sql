-- =============================================================================
-- 080-reviews.sql — 已購評價展示資料（verified-purchase only）
-- Reviews seed for admin / storefront demo (must FK to order_items)
-- 由 002-dev-seed.sql 統一載入；本片段不可自行 BEGIN／COMMIT／ON_ERROR_STOP。
-- =============================================================================
-- 為什麼不能直接塞 reviews.json 全部文字卻不綁訂單？
-- Schema：每則評論必須有唯一 order_item_id（真實訂單明細），
-- JSON 多數 orderId 是 null，不能憑空捏造交易。
--
-- 本檔對應規則（開發展示用，可重跑）：
-- 1. REV031 → order_item 602081（JSON 唯一明確 orderId=208）
-- 2. 其餘優先 customer_id + product_id 對到 shipped/completed 明細
-- 3. 再退而求其次：同 product 的 completed，再不行用 shipped
-- 4. 一筆明細最多一則評論（uq_reviews_order_item_id）
-- =============================================================================

INSERT INTO public.reviews (id, order_item_id, rating, comment, created_at)
VALUES
    ('REV001', 600063, 5, '出貨快速，包裝完整，大推！', TIMESTAMPTZ '2026-03-05T10:20:00+08:00'),
    ('REV002', 600031, 4, '品質良好，物流稍慢但可理解。', TIMESTAMPTZ '2026-03-06T09:10:00+08:00'),
    ('REV003', 600752, 3, '尚可，但與期待有些落差。', TIMESTAMPTZ '2026-03-07T16:58:00+08:00'),
    ('REV004', 600062, 5, '露營必備，物超所值！', TIMESTAMPTZ '2026-03-08T12:47:00+08:00'),
    ('REV005', 600201, 2, '顏色與圖片不符，有點失望。', TIMESTAMPTZ '2026-03-09T11:26:00+08:00'),
    ('REV006', 600213, 4, '功能符合期待，性價比高。', TIMESTAMPTZ '2026-03-10T18:21:00+08:00'),
    ('REV007', 600291, 1, '收到瑕疵品，申請退換貨中。', TIMESTAMPTZ '2026-03-11T11:56:00+08:00'),
    ('REV008', 600321, 4, '整體不錯，小瑕疵可接受。', TIMESTAMPTZ '2026-03-12T13:53:00+08:00'),
    ('REV009', 600151, 1, '完全不符合描述，不推薦。', TIMESTAMPTZ '2026-03-13T09:42:00+08:00'),
    ('REV010', 602041, 5, '使用體驗極佳，會再回購。', TIMESTAMPTZ '2026-03-14T20:15:00+08:00'),
    ('REV011', 600561, 4, '品質良好，物流稍慢但可理解。', TIMESTAMPTZ '2026-03-15T18:26:00+08:00'),
    ('REV012', 601002, 4, '整體不錯，小瑕疵可接受。', TIMESTAMPTZ '2026-03-16T10:03:00+08:00'),
    ('REV013', 600441, 3, '品質普通，價格略高。', TIMESTAMPTZ '2026-03-17T08:42:00+08:00'),
    ('REV014', 600282, 5, '出貨快速，包裝完整，大推！', TIMESTAMPTZ '2026-03-18T19:24:00+08:00'),
    ('REV015', 600651, 4, '功能符合期待，性價比高。', TIMESTAMPTZ '2026-03-19T08:26:00+08:00'),
    ('REV016', 600572, 2, '材質比想像中薄，不太耐用。', TIMESTAMPTZ '2026-03-20T11:49:00+08:00'),
    ('REV017', 600421, 5, '露營必備，物超所值！', TIMESTAMPTZ '2026-03-21T16:00:00+08:00'),
    ('REV018', 600302, 2, '顏色與圖片不符，有點失望。', TIMESTAMPTZ '2026-03-22T12:40:00+08:00'),
    ('REV019', 600112, 2, '顏色與圖片不符，有點失望。', TIMESTAMPTZ '2026-03-23T11:45:00+08:00'),
    ('REV020', 600992, 4, '整體不錯，小瑕疵可接受。', TIMESTAMPTZ '2026-03-24T14:30:00+08:00'),
    ('REV021', 600352, 5, '出貨快速，包裝完整，大推！', TIMESTAMPTZ '2026-03-25T19:22:00+08:00'),
    ('REV022', 600032, 2, '材質比想像中薄，不太耐用。', TIMESTAMPTZ '2026-03-26T14:40:00+08:00'),
    ('REV023', 600242, 5, '使用體驗極佳，會再回購。', TIMESTAMPTZ '2026-03-27T20:12:00+08:00'),
    ('REV024', 600212, 5, '出貨快速，包裝完整，大推！', TIMESTAMPTZ '2026-03-28T13:16:00+08:00'),
    ('REV025', 600181, 4, '整體不錯，小瑕疵可接受。', TIMESTAMPTZ '2026-03-29T10:03:00+08:00'),
    ('REV026', 600612, 4, '品質良好，物流稍慢但可理解。', TIMESTAMPTZ '2026-03-30T09:10:00+08:00'),
    ('REV027', 600963, 3, '使用上沒大問題，包裝可再加強。', TIMESTAMPTZ '2026-04-01T21:10:00+08:00'),
    ('REV028', 600283, 3, '品質普通，價格略高。', TIMESTAMPTZ '2026-04-02T11:42:00+08:00'),
    ('REV029', 600521, 3, '使用上沒大問題，包裝可再加強。', TIMESTAMPTZ '2026-04-03T14:09:00+08:00'),
    ('REV031', 602081, 5, '暑假出貨很快，帳篷品質很棒！', TIMESTAMPTZ '2026-07-10T10:00:00+08:00'),
    ('REV032', 600531, 4, '睡袋保暖效果佳，推薦秋冬使用。', TIMESTAMPTZ '2026-07-12T14:30:00+08:00'),
    ('REV033', 602121, 5, '登山杖輕量穩固，八月爬山必備。', TIMESTAMPTZ '2026-07-15T09:20:00+08:00'),
    ('REV034', 601471, 4, '桌椅組收納方便，家庭露營很實用。', TIMESTAMPTZ '2026-07-25T16:00:00+08:00'),
    ('REV035', 602171, 5, '八月促銷入手，CP 值很高！', TIMESTAMPTZ '2026-08-12T11:45:00+08:00'),
    ('REV036', 601331, 4, '爐具火力足，中秋烤肉露營剛好。', TIMESTAMPTZ '2026-08-28T10:10:00+08:00'),
    ('REV037', 600633, 5, '九月補貨到貨，包裝完整無損。', TIMESTAMPTZ '2026-09-05T15:00:00+08:00'),
    ('REV038', 600731, 5, '秋季露營必備，質感很好。', TIMESTAMPTZ '2026-09-18T09:30:00+08:00')
ON CONFLICT (id) DO UPDATE SET
    order_item_id = EXCLUDED.order_item_id,
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment,
    created_at = EXCLUDED.created_at;

INSERT INTO public.review_photos (review_id, sort_order, url)
VALUES
    ('REV004', 0, '/assets/images/products/P004-1.jpg'),
    ('REV004', 1, '/assets/images/camp_hero2.png'),
    ('REV010', 0, '/assets/images/products/P002-1.jpg'),
    ('REV031', 0, '/assets/images/products/P001-1.jpg'),
    ('REV034', 0, '/assets/images/products/P009-1.jpg')
ON CONFLICT (review_id, sort_order) DO UPDATE SET
    url = EXCLUDED.url;
