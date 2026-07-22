-- ============================================================
-- 範例：把「你的 Google 帳號 email」加入後台白名單（勿提交真實個資）
-- Example: whitelist YOUR Google email for Admin Firebase login.
--
-- 用法（擇一）：
-- 1) 複製本檔 → 改名／改 email → 用 psql 執行（不要 commit 含真實 email 的檔）
-- 2) 或直接在本機用下面指令（把 email 換成你的 Google）：
--
-- docker exec -i yuruicamp-db psql -U postgres -d yuruicamp -c "
-- INSERT INTO public.admin_users (id, name, email, role, active)
-- VALUES (
--   'DEV-GOOGLE-ADMIN',
--   'Local Google Admin',
--   'your.name@gmail.com',
--   'admin',
--   true
-- )
-- ON CONFLICT (id) DO UPDATE SET
--   email = EXCLUDED.email,
--   name = EXCLUDED.name,
--   role = EXCLUDED.role,
--   active = EXCLUDED.active,
--   firebase_uid = NULL,
--   updated_at = now();
-- "
--
-- 注意：
-- - 正式 seed（002-dev-seed.sql）不會自動載入本檔（避免個資進 git）
-- - email 必須與 Firebase Google 登入拿到的 email 完全一致（大小寫不敏感）
-- - 若曾綁過錯誤的 firebase_uid，上面把 firebase_uid 清成 NULL 可重新綁定
-- ============================================================

INSERT INTO public.admin_users (id, name, email, role, active)
VALUES (
    'DEV-GOOGLE-ADMIN',
    'Local Google Admin',
    'your.name@gmail.com',
    'admin',
    true
)
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    active = EXCLUDED.active,
    firebase_uid = NULL,
    updated_at = now();
