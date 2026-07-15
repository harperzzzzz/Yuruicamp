-- The live orders constraint already permits cancelled; add it to the shared
-- enum in a separate migration so PostgreSQL commits the enum value before the
-- following migration uses the type.

ALTER TYPE public.order_status ADD VALUE 'cancelled';
