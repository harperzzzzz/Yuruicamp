-- Booking E-1：公休資料需要一位固定的開發管理員作為建立者。
INSERT INTO public.admin_users (id, name, email, role, active)
VALUES (
    'DEV-BOOKING-ADMIN',
    'Booking Seed Admin',
    'booking-seed@example.test',
    'admin',
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    active = EXCLUDED.active,
    updated_at = now();

INSERT INTO public.campground_closures (
    id,
    campground_id,
    closure_type,
    start_date,
    end_date,
    weekday,
    effective_from,
    effective_to,
    reason,
    created_by
)
OVERRIDING SYSTEM VALUE
VALUES (
    900001,
    'C002',
    'date_range',
    DATE '2026-09-01',
    DATE '2026-09-02',
    NULL,
    NULL,
    NULL,
    'E-1 Swagger 公休範例',
    'DEV-BOOKING-ADMIN'
)
ON CONFLICT (id) DO UPDATE SET
    campground_id = EXCLUDED.campground_id,
    closure_type = EXCLUDED.closure_type,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    weekday = EXCLUDED.weekday,
    effective_from = EXCLUDED.effective_from,
    effective_to = EXCLUDED.effective_to,
    reason = EXCLUDED.reason,
    created_by = EXCLUDED.created_by,
    updated_at = now();

SELECT setval(
    'public.campground_closures_id_seq',
    GREATEST((SELECT max(id) FROM public.campground_closures), 1),
    true
);
