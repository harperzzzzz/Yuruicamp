-- 商品目錄共用參考資料；必須先於商品資料載入。
INSERT INTO public.product_categories (id, code, name, sort_order) OVERRIDING SYSTEM VALUE VALUES
  (1, 'tent', '帳篷', 0),
  (2, 'sleeping-bag', '睡袋', 1),
  (3, 'cookware', '炊具', 2),
  (4, 'lighting', '燈具', 3),
  (5, 'backpack', '背包', 4),
  (6, 'other', '其他', 5)
ON CONFLICT DO NOTHING;

SELECT setval(
    'public.product_categories_id_seq',
    GREATEST((SELECT max(id) FROM public.product_categories), 1),
    true
);

INSERT INTO public.brands (id, name, logo_url, sort_order) VALUES
  ('coleman', 'Coleman', NULL, 0),
  ('msr', 'MSR', NULL, 1),
  ('yuruicamp', 'Yuruicamp', NULL, 2),
  ('snow-peak', 'Snow Peak', NULL, 3)
ON CONFLICT DO NOTHING;
