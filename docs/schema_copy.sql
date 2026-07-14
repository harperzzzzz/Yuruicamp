-- Yuruicamp schema snapshot through V720.
-- Generated from a validated V001-V720 database; never use this file to upgrade an existing database.
-- Flyway migration files remain the only upgrade source of truth.

--
-- PostgreSQL database dump
--

\restrict 7AbWotlZqgLjboNPhE21SDcBNmxtPQQqxkQzs2SEMfV0WyhiXnXTDJPV9bZv9xy

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: migration; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA migration;


--
-- Name: article_block_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.article_block_type AS ENUM (
    'text',
    'heading',
    'product'
);


--
-- Name: auth_provider; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.auth_provider AS ENUM (
    'google',
    'facebook',
    'line'
);


--
-- Name: booking_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.booking_status AS ENUM (
    'pending',
    'confirmed',
    'completed',
    'cancelled'
);


--
-- Name: closure_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.closure_type AS ENUM (
    'date_range',
    'weekly'
);


--
-- Name: coupon_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.coupon_category AS ENUM (
    'promotion',
    'birthday',
    'firstPurchase'
);


--
-- Name: coupon_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.coupon_status AS ENUM (
    'active',
    'disabled'
);


--
-- Name: coupon_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.coupon_type AS ENUM (
    'fixed',
    'percent'
);


--
-- Name: min_stock_target_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.min_stock_target_type AS ENUM (
    'store',
    'rental'
);


--
-- Name: order_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.order_status AS ENUM (
    'unshipped',
    'shipped',
    'completed',
    'returned'
);


--
-- Name: payment_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_method AS ENUM (
    'credit-card',
    'line-pay',
    'cod'
);


--
-- Name: payment_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_status AS ENUM (
    'unpaid',
    'paid',
    'refunded'
);


--
-- Name: product_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_status AS ENUM (
    'active',
    'inactive'
);


--
-- Name: shipping_method; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.shipping_method AS ENUM (
    'delivery',
    'pickup'
);


--
-- Name: reject_p7_archive_write(); Type: FUNCTION; Schema: migration; Owner: -
--

CREATE FUNCTION migration.reject_p7_archive_write() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'P7 migration archive is read-only' USING ERRCODE = '55000';
END $$;


--
-- Name: FUNCTION reject_p7_archive_write(); Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON FUNCTION migration.reject_p7_archive_write() IS 'Rejects every owner/application DML attempt against P7 archive relations.';


CREATE FUNCTION public.reject_customer_hard_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'customers must be soft deleted with soft_delete_customer(%)', OLD.id
    USING ERRCODE = '23000';
END;
$$;


CREATE FUNCTION public.soft_delete_customer(p_customer_id character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  UPDATE customers
  SET active = FALSE,
      deleted_at = now(),
      updated_at = now()
  WHERE id = p_customer_id
    AND active = TRUE
    AND deleted_at IS NULL;

  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  RETURN affected_rows = 1;
END;
$$;


--
-- Name: enforce_campground_rental_location_type(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_campground_rental_location_type() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  location_domain VARCHAR(16);
  location_type VARCHAR(32);
BEGIN
  SELECT inventory_domain, type
  INTO location_domain, location_type
  FROM inventory_locations
  WHERE id = NEW.location_id;

  IF location_domain IS DISTINCT FROM 'rental'
     OR location_type IS DISTINCT FROM 'campground' THEN
    RAISE EXCEPTION 'location % must be an active rental campground location', NEW.location_id
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: enforce_inventory_conversion_domains(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_inventory_conversion_domains() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  source_domain VARCHAR(16);
  destination_domain VARCHAR(16);
  source_location_domain VARCHAR(16);
  destination_location_domain VARCHAR(16);
BEGIN
  SELECT inventory_domain INTO source_domain
  FROM inventory_movements WHERE id = NEW.source_movement_id;
  SELECT inventory_domain INTO destination_domain
  FROM inventory_movements WHERE id = NEW.destination_movement_id;
  SELECT inventory_domain INTO source_location_domain
  FROM inventory_locations WHERE id = NEW.source_location_id;
  SELECT inventory_domain INTO destination_location_domain
  FROM inventory_locations WHERE id = NEW.destination_location_id;
  IF source_domain <> 'store' OR destination_domain <> 'rental'
     OR source_location_domain <> 'store' OR destination_location_domain <> 'rental' THEN
    RAISE EXCEPTION 'inventory conversion must be store -> rental'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: enforce_minimum_stock_location_domain(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_minimum_stock_location_domain() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE actual_domain VARCHAR(16);
BEGIN
  SELECT inventory_domain INTO actual_domain
  FROM inventory_locations WHERE id = NEW.location_id;
  IF (TG_TABLE_NAME = 'product_variant_min_stocks' AND actual_domain <> 'store')
     OR (TG_TABLE_NAME = 'rental_sku_variant_min_stocks' AND actual_domain <> 'rental') THEN
    RAISE EXCEPTION 'minimum stock location domain mismatch' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: get_zone_availability(date, date, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_zone_availability(p_from date, p_to date, p_campground_id character varying DEFAULT NULL::character varying, p_zone_id character varying DEFAULT NULL::character varying) RETURNS TABLE(zone_id character varying, stay_date date, total_sites integer, booked_quantity bigint, blocked_quantity bigint, available_quantity bigint, is_closed boolean)
    LANGUAGE sql STABLE
    AS $$
  WITH dates AS (
    SELECT day_value::date AS stay_date
    FROM generate_series(p_from, p_to, interval '1 day') day_value
    WHERE p_to >= p_from
  ), candidates AS (
    SELECT zone.id AS zone_id, zone.campground_id, zone.total_sites, dates.stay_date
    FROM campground_zones zone
    CROSS JOIN dates
    WHERE (p_campground_id IS NULL OR zone.campground_id = p_campground_id)
      AND (p_zone_id IS NULL OR zone.id = p_zone_id)
  )
  SELECT candidate.zone_id, candidate.stay_date, candidate.total_sites,
         CASE WHEN closure.is_closed THEN 0::bigint
              ELSE occupied.booked_quantity END AS booked_quantity,
         CASE WHEN closure.is_closed THEN 0::bigint
              ELSE blocked.blocked_quantity END AS blocked_quantity,
         CASE WHEN closure.is_closed THEN 0::bigint
              ELSE greatest(
                candidate.total_sites::bigint
                - occupied.booked_quantity - blocked.blocked_quantity,
                0::bigint
              )
          END AS available_quantity,
          closure.is_closed
  FROM candidates candidate
  CROSS JOIN LATERAL (
    SELECT coalesce(sum(selected.quantity), 0)::bigint AS booked_quantity
    FROM bookings booking
    JOIN booking_selected_zones selected ON selected.booking_id = booking.id
    JOIN booking_policy_occupying_statuses status
      ON status.policy_id = 1 AND status.status = booking.status
    WHERE selected.zone_id = candidate.zone_id
      AND candidate.stay_date >= booking.check_in
      AND candidate.stay_date < booking.check_out
  ) occupied
  CROSS JOIN LATERAL (
    SELECT coalesce(sum(block.blocked_quantity), 0)::bigint AS blocked_quantity
    FROM zone_blocks block
    WHERE block.zone_id = candidate.zone_id
      AND block.campground_id = candidate.campground_id
      AND candidate.stay_date >= block.start_date
      AND candidate.stay_date < block.end_date
  ) blocked
  CROSS JOIN LATERAL (
    SELECT EXISTS (
      SELECT 1 FROM campground_closures value
      WHERE value.campground_id = candidate.campground_id
        AND (
          (value.closure_type = 'date_range'
            AND candidate.stay_date >= value.start_date
            AND candidate.stay_date < value.end_date)
          OR
          (value.closure_type = 'weekly'
            AND extract(dow FROM candidate.stay_date)::smallint = value.weekday
            AND candidate.stay_date BETWEEN value.effective_from AND value.effective_to)
        )
    ) AS is_closed
  ) closure
  ORDER BY candidate.zone_id, candidate.stay_date
$$;


--
-- Name: FUNCTION get_zone_availability(p_from date, p_to date, p_campground_id character varying, p_zone_id character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_zone_availability(p_from date, p_to date, p_campground_id character varying, p_zone_id character varying) IS 'P5 inclusive calendar-range query; booking occupancy is [check_in, check_out), closures force zero, and availability never becomes negative.';


--
-- Name: protect_inventory_conversion_draft(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_inventory_conversion_draft() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  source_id BIGINT;
  destination_id BIGINT;
BEGIN
  source_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.source_movement_id ELSE NEW.source_movement_id END;
  destination_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.destination_movement_id ELSE NEW.destination_movement_id END;
  IF EXISTS (
    SELECT 1 FROM inventory_movements
    WHERE id IN (source_id, destination_id) AND status <> 'draft'
  ) THEN
    RAISE EXCEPTION 'inventory conversion is editable only while both movements are draft'
      USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END
$$;


--
-- Name: protect_inventory_movement_detail(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_inventory_movement_detail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  target_movement_id BIGINT;
  movement_status VARCHAR(16);
BEGIN
  target_movement_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.movement_id ELSE NEW.movement_id END;
  SELECT status INTO movement_status FROM inventory_movements WHERE id = target_movement_id;
  IF movement_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'inventory movement details are editable only while draft'
      USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END
$$;


--
-- Name: protect_inventory_movement_header(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_inventory_movement_header() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'draft' THEN
      RAISE EXCEPTION 'posted or cancelled inventory movement is immutable'
        USING ERRCODE = '55000';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.status IN ('posted', 'cancelled') THEN
    RAISE EXCEPTION 'posted or cancelled inventory movement is immutable'
      USING ERRCODE = '55000';
  END IF;
  IF NEW.status NOT IN ('draft', 'posted', 'cancelled') THEN
    RAISE EXCEPTION 'invalid inventory movement transition'
      USING ERRCODE = '23514';
  END IF;
  IF NEW.status = 'posted' AND NOT EXISTS (
    SELECT 1 FROM store_inventory_movement_items item WHERE item.movement_id = NEW.id
    UNION ALL
    SELECT 1 FROM rental_inventory_movement_items item WHERE item.movement_id = NEW.id
    UNION ALL
    SELECT 1 FROM inventory_conversions conversion
    WHERE conversion.source_movement_id = NEW.id OR conversion.destination_movement_id = NEW.id
  ) THEN
    RAISE EXCEPTION 'inventory movement cannot be posted without a detail or conversion'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: protect_mapped_rental_location_type(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_mapped_rental_location_type() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM campground_rental_locations mapping
    WHERE mapping.location_id = NEW.id
  ) AND (NEW.inventory_domain <> 'rental' OR NEW.type <> 'campground') THEN
    RAISE EXCEPTION 'mapped rental location % must remain rental/campground', NEW.id
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: protect_minimum_stock_location_domain(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_minimum_stock_location_domain() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.inventory_domain <> OLD.inventory_domain AND (
    (EXISTS (SELECT 1 FROM product_variant_min_stocks WHERE location_id = OLD.id)
      AND NEW.inventory_domain <> 'store')
    OR
    (EXISTS (SELECT 1 FROM rental_sku_variant_min_stocks WHERE location_id = OLD.id)
      AND NEW.inventory_domain <> 'rental')
  ) THEN
    RAISE EXCEPTION 'inventory location domain is fixed by minimum-stock references'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: protect_stock_reservation_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_stock_reservation_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'active' THEN
      RAISE EXCEPTION 'new stock reservation must be active' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'stock reservation audit rows cannot be deleted' USING ERRCODE = '55000';
  END IF;
  IF OLD.status <> 'active' THEN
    RAISE EXCEPTION 'terminal stock reservation is immutable' USING ERRCODE = '55000';
  END IF;
  IF NEW.status NOT IN ('active', 'released', 'expired', 'fulfilled') THEN
    RAISE EXCEPTION 'invalid stock reservation transition' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END
$$;


--
-- Name: reject_legacy_review_write(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reject_legacy_review_write() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'legacy reviews are read-only migration evidence';
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: movement_migration_map; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.movement_migration_map (
    legacy_movement_id character varying(64) NOT NULL,
    legacy_item_ordinal integer NOT NULL,
    store_item_id bigint,
    rental_item_id bigint,
    conversion_id bigint,
    quarantine_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_movement_migration_map_exactly_one CHECK ((num_nonnulls(store_item_id, rental_item_id, conversion_id, quarantine_reason) = 1)),
    CONSTRAINT ck_movement_migration_map_ordinal CHECK ((legacy_item_ordinal >= 0))
);


--
-- Name: TABLE movement_migration_map; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.movement_migration_map IS 'P7 read-only archive of the deterministic P5 legacy-item disposition map.';


--
-- Name: p1_location_aliases; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p1_location_aliases (
    alias character varying(200) NOT NULL,
    location_id character varying(32) NOT NULL,
    source character varying(100) NOT NULL
);


--
-- Name: p1_location_quarantine; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p1_location_quarantine (
    source_table character varying(100) NOT NULL,
    source_row_id character varying(64) NOT NULL,
    field_name character varying(64) NOT NULL,
    raw_value character varying(200) NOT NULL,
    reason text NOT NULL,
    disposition_status character varying(32) DEFAULT 'PENDING_REVIEW'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: p2_campground_tag_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p2_campground_tag_source (
    campground_id character varying(32) NOT NULL,
    environment_tags jsonb NOT NULL,
    facility_tags jsonb NOT NULL
);


--
-- Name: p2_product_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p2_product_source (
    product_id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p3_legacy_rental_listings; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p3_legacy_rental_listings (
    id character varying(32) NOT NULL,
    rental_sku_id character varying(32) NOT NULL,
    product_id character varying(32) NOT NULL,
    variant_id character varying(64) NOT NULL,
    sku character varying(64) NOT NULL,
    campground_id character varying(32) NOT NULL,
    name character varying(200) NOT NULL,
    color character varying(64),
    size character varying(64),
    spec_label character varying(128),
    image_url text,
    terrain_tag character varying(128),
    description text,
    price_per_day_weekday numeric(12,2) DEFAULT 0 NOT NULL,
    price_per_day_holiday numeric(12,2) DEFAULT 0 NOT NULL,
    discount numeric(12,2) DEFAULT 0 NOT NULL,
    stock integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE p3_legacy_rental_listings; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p3_legacy_rental_listings IS '營區租借 listing（衍生）。stock 來自 rental_sku_variant_stocks，禁止手改。 / Derived listings; sync stock from rental SKU variant camp stock.';


--
-- Name: COLUMN p3_legacy_rental_listings.stock; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON COLUMN migration.p3_legacy_rental_listings.stock IS 'DERIVED from rental_sku_variant_stocks — run sync (npm run sync:listings) / 衍生欄位';


--
-- Name: p3_legacy_rental_sku_variant_stocks; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p3_legacy_rental_sku_variant_stocks (
    id bigint NOT NULL,
    rental_sku_id character varying(32) NOT NULL,
    variant_id character varying(64) NOT NULL,
    campground_id character varying(32) NOT NULL,
    quantity integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE p3_legacy_rental_sku_variant_stocks; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p3_legacy_rental_sku_variant_stocks IS '各營區／主倉的 variant 庫存真相 / Per-camp variant qty (includes C001 warehouse)';


--
-- Name: COLUMN p3_legacy_rental_sku_variant_stocks.campground_id; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON COLUMN migration.p3_legacy_rental_sku_variant_stocks.campground_id IS 'C001=warehouse (not in campgrounds); C002–C009=bookable camps';


--
-- Name: p3_legacy_rental_sku_variant_stocks_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p3_legacy_rental_sku_variant_stocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p3_legacy_rental_sku_variant_stocks_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p3_legacy_rental_sku_variant_stocks_id_seq OWNED BY migration.p3_legacy_rental_sku_variant_stocks.id;


--
-- Name: p3_listing_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p3_listing_source (
    listing_id character varying(64) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p3_rental_min_stock_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p3_rental_min_stock_source (
    rental_sku_id character varying(32) NOT NULL,
    location_id character varying(32) NOT NULL,
    quantity integer NOT NULL
);


--
-- Name: p3_rental_sku_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p3_rental_sku_source (
    rental_sku_id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p3_rental_variant_map; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p3_rental_variant_map (
    rental_sku_id character varying(32) NOT NULL,
    legacy_variant_id character varying(64) NOT NULL,
    rental_variant_id character varying(64) NOT NULL
);


--
-- Name: p4_action_map; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_action_map (
    domain character varying(16) NOT NULL,
    legacy_action text NOT NULL,
    status character varying(24) NOT NULL,
    note_pattern character varying(64)
);


--
-- Name: p4_booking_day_count_resolution; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_booking_day_count_resolution (
    booking_id character varying(32) NOT NULL,
    source_weekday_count integer NOT NULL,
    source_holiday_count integer NOT NULL,
    resolved_weekday_count integer,
    resolved_holiday_count integer,
    resolution_method character varying(64) NOT NULL,
    disposition_status character varying(24) NOT NULL,
    reason text NOT NULL
);


--
-- Name: p4_booking_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_booking_source (
    id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p4_coupon_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_coupon_source (
    code character varying(64) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p4_legacy_booking_history; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_booking_history (
    id bigint NOT NULL,
    booking_id bigint NOT NULL,
    "time" timestamp with time zone NOT NULL,
    action text NOT NULL
);


--
-- Name: p4_legacy_booking_history_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_booking_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_booking_history_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_booking_history_id_seq OWNED BY migration.p4_legacy_booking_history.id;


--
-- Name: p4_legacy_booking_selected_rentals; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_booking_selected_rentals (
    id bigint NOT NULL,
    booking_id bigint NOT NULL,
    equipment_id character varying(32),
    rental_sku_id character varying(32),
    product_id character varying(32),
    variant_id character varying(64),
    sku character varying(64),
    name character varying(200),
    spec_label character varying(128),
    quantity integer NOT NULL,
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT booking_selected_rentals_quantity_check CHECK ((quantity > 0))
);


--
-- Name: p4_legacy_booking_selected_rentals_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_booking_selected_rentals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_booking_selected_rentals_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_booking_selected_rentals_id_seq OWNED BY migration.p4_legacy_booking_selected_rentals.id;


--
-- Name: p4_legacy_booking_selected_zones; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_booking_selected_zones (
    id bigint NOT NULL,
    booking_id bigint NOT NULL,
    zone_id character varying(32) NOT NULL,
    zone_type character varying(64),
    quantity integer NOT NULL,
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT booking_selected_zones_quantity_check CHECK ((quantity > 0))
);


--
-- Name: p4_legacy_booking_selected_zones_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_booking_selected_zones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_booking_selected_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_booking_selected_zones_id_seq OWNED BY migration.p4_legacy_booking_selected_zones.id;


--
-- Name: p4_legacy_bookings; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_bookings (
    id bigint NOT NULL,
    customer_id character varying(32) NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    payment_status public.payment_status DEFAULT 'unpaid'::public.payment_status NOT NULL,
    status public.booking_status DEFAULT 'pending'::public.booking_status NOT NULL,
    equipment_returned boolean DEFAULT false NOT NULL,
    campground_id character varying(32) NOT NULL,
    campground_name character varying(200) NOT NULL,
    region character varying(32),
    check_in date NOT NULL,
    check_out date NOT NULL,
    total_days integer NOT NULL,
    weekday_count integer DEFAULT 0 NOT NULL,
    holiday_count integer DEFAULT 0 NOT NULL,
    guest_count integer DEFAULT 1 NOT NULL,
    zone_total numeric(12,2) DEFAULT 0 NOT NULL,
    rental_total numeric(12,2) DEFAULT 0 NOT NULL,
    applied_discount numeric(12,2) DEFAULT 0 NOT NULL,
    final_amount numeric(12,2) DEFAULT 0 NOT NULL,
    customer_note text,
    seller_note text,
    CONSTRAINT bookings_check CHECK ((check_out > check_in))
);


--
-- Name: TABLE p4_legacy_bookings; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p4_legacy_bookings IS '營區預約。bookingInfo 快照 + campground_id FK。區間 [check_in, check_out)。 / Camp bookings.';


--
-- Name: p4_legacy_bookings_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_bookings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_bookings_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_bookings_id_seq OWNED BY migration.p4_legacy_bookings.id;


--
-- Name: p4_legacy_coupons; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_coupons (
    code character varying(64) NOT NULL,
    discount numeric(12,2) NOT NULL,
    type public.coupon_type DEFAULT 'fixed'::public.coupon_type NOT NULL,
    min_order numeric(12,2) DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    used integer DEFAULT 0 NOT NULL,
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    status public.coupon_status DEFAULT 'active'::public.coupon_status NOT NULL,
    category public.coupon_category NOT NULL
);


--
-- Name: TABLE p4_legacy_coupons; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p4_legacy_coupons IS '折價券主檔。promotion 不進會員中心列表；birthday/firstPurchase 可列。 / Coupon master.';


--
-- Name: p4_legacy_order_coupons; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_order_coupons (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    code character varying(64) NOT NULL,
    type public.coupon_type,
    discount numeric(12,2),
    amount numeric(12,2),
    coupon_code character varying(64)
);


--
-- Name: TABLE p4_legacy_order_coupons; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p4_legacy_order_coupons IS '訂單套用券快照 / Coupon usage snapshot on order';


--
-- Name: p4_legacy_order_coupons_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_order_coupons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_order_coupons_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_order_coupons_id_seq OWNED BY migration.p4_legacy_order_coupons.id;


--
-- Name: p4_legacy_order_history; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_order_history (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    "time" timestamp with time zone NOT NULL,
    action text NOT NULL
);


--
-- Name: p4_legacy_order_history_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_order_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_order_history_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_order_history_id_seq OWNED BY migration.p4_legacy_order_history.id;


--
-- Name: p4_legacy_order_items; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_order_items (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    product_id character varying(32) NOT NULL,
    variant_id character varying(64) NOT NULL,
    sku character varying(64) NOT NULL,
    name character varying(200) NOT NULL,
    spec_label character varying(128),
    color character varying(64),
    size character varying(64),
    brand character varying(64),
    image text,
    price numeric(12,2) NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0))
);


--
-- Name: TABLE p4_legacy_order_items; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p4_legacy_order_items IS '訂單明細：FK + 顯示快照（name/spec_label/price/image）/ Line items with snapshots';


--
-- Name: p4_legacy_order_items_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_order_items_id_seq OWNED BY migration.p4_legacy_order_items.id;


--
-- Name: p4_legacy_orders; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_legacy_orders (
    id bigint NOT NULL,
    customer_id character varying(32) NOT NULL,
    buyer_name character varying(100) NOT NULL,
    address text,
    buyer_phone character varying(32),
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    shipping_fee numeric(12,2) DEFAULT 0 NOT NULL,
    discount numeric(12,2) DEFAULT 0 NOT NULL,
    total numeric(12,2) DEFAULT 0 NOT NULL,
    points integer DEFAULT 0 NOT NULL,
    points_awarded boolean DEFAULT false NOT NULL,
    payment public.payment_method,
    payment_status public.payment_status DEFAULT 'unpaid'::public.payment_status NOT NULL,
    status public.order_status DEFAULT 'unshipped'::public.order_status NOT NULL,
    shipping_method public.shipping_method,
    tracking_number character varying(64),
    delivered_at timestamp with time zone,
    reviewed boolean DEFAULT false NOT NULL,
    customer_note text,
    seller_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE p4_legacy_orders; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p4_legacy_orders IS '商城訂單。buyer_name/address 為下單快照；用 customer_id 查會員訂單。 / Orders with buyer snapshots.';


--
-- Name: COLUMN p4_legacy_orders.payment; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON COLUMN migration.p4_legacy_orders.payment IS '付款方式 credit-card|line-pay|cod；≠ payment_status / Payment method (not status)';


--
-- Name: COLUMN p4_legacy_orders.payment_status; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON COLUMN migration.p4_legacy_orders.payment_status IS '付款狀態 unpaid|paid|refunded；COD 通常為 unpaid / Payment status';


--
-- Name: p4_legacy_orders_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p4_legacy_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p4_legacy_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p4_legacy_orders_id_seq OWNED BY migration.p4_legacy_orders.id;


--
-- Name: p4_order_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_order_source (
    id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p4_rental_price_reconciliation; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_rental_price_reconciliation (
    booking_id character varying(32) NOT NULL,
    rental_ordinal integer NOT NULL,
    rental_listing_id character varying(64) NOT NULL,
    official_weekday_count integer NOT NULL,
    official_holiday_count integer NOT NULL,
    current_weekday_price numeric(12,2) NOT NULL,
    current_holiday_price numeric(12,2) NOT NULL,
    current_discount numeric(12,2) NOT NULL,
    chosen_weekday_price numeric(12,2),
    chosen_holiday_price numeric(12,2),
    chosen_discount numeric(12,2),
    stored_subtotal numeric(14,2) NOT NULL,
    calculated_subtotal numeric(14,2) NOT NULL,
    disposition_status character varying(24) NOT NULL,
    reason text NOT NULL
);


--
-- Name: p4_rental_reservation_quarantine; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_rental_reservation_quarantine (
    booking_id character varying(32) NOT NULL,
    rental_ordinal integer NOT NULL,
    rental_listing_id character varying(64) NOT NULL,
    rental_sku_variant_id character varying(64) NOT NULL,
    location_id character varying(32) NOT NULL,
    check_in date NOT NULL,
    check_out date NOT NULL,
    quantity integer NOT NULL,
    reason_code character varying(32) NOT NULL,
    reason text NOT NULL,
    disposition_status character varying(24) NOT NULL
);


--
-- Name: p4_snapshot_fallbacks; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_snapshot_fallbacks (
    domain character varying(16) NOT NULL,
    source_id character varying(32) NOT NULL,
    field_name character varying(64) NOT NULL,
    fallback_source character varying(128) NOT NULL,
    reason text NOT NULL
);


--
-- Name: p4_zone_price_reconciliation; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p4_zone_price_reconciliation (
    booking_id character varying(32) NOT NULL,
    zone_ordinal integer NOT NULL,
    zone_id character varying(32) NOT NULL,
    official_weekday_count integer NOT NULL,
    official_holiday_count integer NOT NULL,
    current_weekday_price numeric(12,2) NOT NULL,
    current_holiday_price numeric(12,2) NOT NULL,
    chosen_weekday_price numeric(12,2),
    chosen_holiday_price numeric(12,2),
    stored_subtotal numeric(14,2) NOT NULL,
    calculated_subtotal numeric(14,2) NOT NULL,
    disposition_status character varying(24) NOT NULL,
    reason text NOT NULL
);


--
-- Name: p5_closure_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_closure_source (
    legacy_id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p5_legacy_booking_policies; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_legacy_booking_policies (
    id smallint NOT NULL,
    booking_window_days integer DEFAULT 90 NOT NULL,
    min_lead_days integer DEFAULT 0 NOT NULL,
    max_stay_nights integer DEFAULT 7 NOT NULL,
    timezone character varying(64) DEFAULT 'Asia/Taipei'::character varying NOT NULL,
    occupying_statuses jsonb DEFAULT '["pending", "confirmed", "completed"]'::jsonb NOT NULL,
    date_rule jsonb DEFAULT '{"checkInInclusive": true, "checkOutExclusive": true}'::jsonb NOT NULL,
    availability_status jsonb
);


--
-- Name: TABLE p5_legacy_booking_policies; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_legacy_booking_policies IS '預約政策（通常一列）。booking_window_days=90。JSON: data/admin/booking-policy.json';


--
-- Name: p5_legacy_booking_policies_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p5_legacy_booking_policies_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p5_legacy_booking_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p5_legacy_booking_policies_id_seq OWNED BY migration.p5_legacy_booking_policies.id;


--
-- Name: p5_legacy_campground_closures; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_legacy_campground_closures (
    id character varying(32) NOT NULL,
    campground_id character varying(32) NOT NULL,
    type public.closure_type NOT NULL,
    start_date date,
    end_date date,
    day_of_week smallint,
    effective_from date,
    effective_to date,
    reason text,
    created_by character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE p5_legacy_campground_closures; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_legacy_campground_closures IS '營區公休；命中時該營區所有 zone 當晚 closed。JSON: campground-closures.json';


--
-- Name: p5_legacy_min_stocks; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_legacy_min_stocks (
    id bigint NOT NULL,
    target_type public.min_stock_target_type NOT NULL,
    target_id character varying(32) NOT NULL,
    location_key character varying(64) NOT NULL,
    min_quantity integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE p5_legacy_min_stocks; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_legacy_min_stocks IS '最低庫存門檻。store→products；rental→rental_skus。 / Min stock thresholds.';


--
-- Name: p5_legacy_min_stocks_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p5_legacy_min_stocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p5_legacy_min_stocks_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p5_legacy_min_stocks_id_seq OWNED BY migration.p5_legacy_min_stocks.id;


--
-- Name: p5_legacy_movement_items; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_legacy_movement_items (
    id bigint NOT NULL,
    movement_id bigint NOT NULL,
    product_id character varying(32),
    product_name character varying(200) NOT NULL,
    quantity integer NOT NULL,
    from_store character varying(128),
    to_store character varying(128),
    type character varying(32)
);


--
-- Name: TABLE p5_legacy_movement_items; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_legacy_movement_items IS '異動明細：product_name 快照 + 建議 product_id FK。 / Movement lines.';


--
-- Name: p5_legacy_movement_items_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p5_legacy_movement_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p5_legacy_movement_items_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p5_legacy_movement_items_id_seq OWNED BY migration.p5_legacy_movement_items.id;


--
-- Name: p5_legacy_movements; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_legacy_movements (
    id bigint NOT NULL,
    employee_id character varying(32),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE p5_legacy_movements; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_legacy_movements IS '庫存異動單頭。JSON: data/admin/movement.json';


--
-- Name: p5_legacy_movements_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p5_legacy_movements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p5_legacy_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p5_legacy_movements_id_seq OWNED BY migration.p5_legacy_movements.id;


--
-- Name: p5_legacy_zone_blocks; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_legacy_zone_blocks (
    id character varying(32) NOT NULL,
    campground_id character varying(32) NOT NULL,
    zone_id character varying(32) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    blocked_sites integer DEFAULT 0 NOT NULL,
    reason text,
    created_by character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE p5_legacy_zone_blocks; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_legacy_zone_blocks IS '營位維修／停售例外，扣減可賣數 / Zone maintenance blocks. JSON: zone-blocks.json';


--
-- Name: p5_location_resolution; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_location_resolution (
    legacy_label character varying(128) NOT NULL,
    location_id character varying(32),
    inventory_domain character varying(16),
    legacy_code character varying(32),
    resolution_method character varying(64) NOT NULL,
    evidence text NOT NULL,
    disposition_status character varying(32) NOT NULL
);


--
-- Name: TABLE p5_location_resolution; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_location_resolution IS 'P5 deterministic location adjudication; old camp labels are proven by historical code/order and rental-stock vectors.';


--
-- Name: p5_min_stock_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_min_stock_source (
    inventory_domain character varying(16) NOT NULL,
    target_id character varying(32) NOT NULL,
    location_id character varying(32) NOT NULL,
    minimum_quantity integer NOT NULL
);


--
-- Name: p5_movement_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_movement_source (
    legacy_movement_id character varying(64) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p5_policy_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_policy_source (
    id smallint NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p5_variant_resolution; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_variant_resolution (
    legacy_movement_id character varying(64) NOT NULL,
    legacy_item_ordinal integer NOT NULL,
    product_id character varying(32) NOT NULL,
    product_name_snapshot character varying(200) NOT NULL,
    product_variant_id character varying(64) NOT NULL,
    rental_sku_variant_id character varying(64),
    resolution_method character varying(64) NOT NULL,
    disposition_status character varying(64) NOT NULL
);


--
-- Name: TABLE p5_variant_resolution; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p5_variant_resolution IS 'P5 exact product-name-with-variant resolution; similarity and first-variant fallbacks are forbidden.';


--
-- Name: p5_zone_block_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p5_zone_block_source (
    legacy_id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p6_article_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_article_source (
    id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p6_legacy_article_content_blocks; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_legacy_article_content_blocks (
    id bigint NOT NULL,
    article_id character varying(32) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    type public.article_block_type NOT NULL,
    value text,
    product_id character varying(32)
);


--
-- Name: p6_legacy_article_content_blocks_id_seq; Type: SEQUENCE; Schema: migration; Owner: -
--

CREATE SEQUENCE migration.p6_legacy_article_content_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: p6_legacy_article_content_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: migration; Owner: -
--

ALTER SEQUENCE migration.p6_legacy_article_content_blocks_id_seq OWNED BY migration.p6_legacy_article_content_blocks.id;


--
-- Name: p6_legacy_article_related_products; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_legacy_article_related_products (
    article_id character varying(32) NOT NULL,
    product_id character varying(32) NOT NULL
);


--
-- Name: p6_legacy_articles; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_legacy_articles (
    id character varying(32) NOT NULL,
    title character varying(300) NOT NULL,
    category character varying(64),
    author character varying(100),
    author_avatar text,
    published_date date,
    read_time integer,
    image text,
    excerpt text,
    tags jsonb,
    is_featured boolean DEFAULT false NOT NULL
);


--
-- Name: p6_legacy_reviews; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_legacy_reviews (
    id character varying(32) NOT NULL,
    customer_id character varying(32) NOT NULL,
    product_id character varying(32) NOT NULL,
    variant_id character varying(64),
    sku character varying(64),
    order_id bigint,
    buyer_name character varying(100),
    buyer_avatar text,
    product_name character varying(200),
    rating smallint NOT NULL,
    comment text,
    photos jsonb,
    replied boolean DEFAULT false NOT NULL,
    reply_text text,
    reply_at timestamp with time zone,
    replied_by character varying(64),
    replied_by_name character varying(100),
    reply_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: TABLE p6_legacy_reviews; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p6_legacy_reviews IS '商品評價：FK 為準，product_name 僅顯示快照。 / Reviews with FK + name snapshot.';


--
-- Name: p6_review_resolution; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_review_resolution (
    review_id character varying(32) NOT NULL,
    disposition character varying(16) NOT NULL,
    order_item_id bigint,
    resolution_method character varying(64) NOT NULL,
    legacy_reason text,
    CONSTRAINT ck_p6_review_resolution_disposition CHECK (((((disposition)::text = 'formal'::text) AND (order_item_id IS NOT NULL) AND (legacy_reason IS NULL)) OR (((disposition)::text = 'legacy'::text) AND (order_item_id IS NULL) AND (btrim(legacy_reason) <> ''::text))))
);


--
-- Name: TABLE p6_review_resolution; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p6_review_resolution IS 'P6 exact review disposition: REV031 formal; 37 rows without orderId remain read-only legacy evidence.';


--
-- Name: p6_review_source; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p6_review_source (
    id character varying(32) NOT NULL,
    payload jsonb NOT NULL
);


--
-- Name: p7_contract_evidence; Type: TABLE; Schema: migration; Owner: -
--

CREATE TABLE migration.p7_contract_evidence (
    id smallint NOT NULL,
    authorization_mode character varying(32) NOT NULL,
    authorization_reference text NOT NULL,
    contracted_at timestamp with time zone NOT NULL,
    movement_map_rows integer NOT NULL,
    movement_map_quarantine_rows integer NOT NULL,
    movement_map_md5 character(32) NOT NULL,
    CONSTRAINT ck_p7_contract_evidence_counts CHECK (((movement_map_rows = 141) AND (movement_map_quarantine_rows = 1))),
    CONSTRAINT ck_p7_contract_evidence_md5 CHECK ((movement_map_md5 ~ '^[0-9a-f]{32}$'::text)),
    CONSTRAINT ck_p7_contract_evidence_mode CHECK (((authorization_mode)::text = 'OWNER_WAIVER'::text)),
    CONSTRAINT ck_p7_contract_evidence_singleton CHECK ((id = 1))
);


--
-- Name: TABLE p7_contract_evidence; Type: COMMENT; Schema: migration; Owner: -
--

COMMENT ON TABLE migration.p7_contract_evidence IS 'P7 contract authorization and archive checksum; external observation/sign-off was explicitly waived.';


--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id character varying(32) NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(254) NOT NULL,
    role character varying(32) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_admin_users_role CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'operator'::character varying, 'warehouse'::character varying])::text[])))
);


--
-- Name: article_content_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_content_blocks (
    id bigint NOT NULL,
    article_id character varying(32) NOT NULL,
    sort_order integer NOT NULL,
    block_type character varying(16) NOT NULL,
    text_content text,
    product_id character varying(32),
    CONSTRAINT ck_article_content_blocks_payload CHECK (((((block_type)::text = ANY ((ARRAY['text'::character varying, 'heading'::character varying])::text[])) AND (text_content IS NOT NULL) AND (product_id IS NULL)) OR (((block_type)::text = 'product'::text) AND (text_content IS NULL) AND (product_id IS NOT NULL)))),
    CONSTRAINT ck_article_content_blocks_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: article_content_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.article_content_blocks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.article_content_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: article_related_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_related_products (
    article_id character varying(32) NOT NULL,
    product_id character varying(32) NOT NULL,
    sort_order integer NOT NULL,
    CONSTRAINT ck_article_related_products_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: article_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_tags (
    article_id character varying(32) NOT NULL,
    tag character varying(100) NOT NULL,
    CONSTRAINT ck_article_tags_tag CHECK ((btrim((tag)::text) <> ''::text))
);


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id character varying(32) NOT NULL,
    title character varying(250) NOT NULL,
    category character varying(64) NOT NULL,
    author character varying(120) NOT NULL,
    author_avatar_url text,
    published_at timestamp with time zone,
    summary text NOT NULL,
    cover_image_url text,
    reading_minutes integer NOT NULL,
    featured boolean DEFAULT false NOT NULL,
    status character varying(16) DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_articles_published CHECK ((((status)::text <> 'published'::text) OR (published_at IS NOT NULL))),
    CONSTRAINT ck_articles_reading CHECK ((reading_minutes >= 0)),
    CONSTRAINT ck_articles_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: COLUMN articles.author; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.articles.author IS 'Public author pen name. D-012 forbids an admin_users relationship.';


--
-- Name: article_dto_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.article_dto_view AS
 SELECT id,
    jsonb_build_object('id', id, 'title', title, 'category', category, 'author', author, 'authorAvatar', author_avatar_url, 'publishedDate', to_char((published_at AT TIME ZONE 'Asia/Taipei'::text), 'YYYY-MM-DD'::text), 'readTime', reading_minutes, 'image', cover_image_url, 'excerpt', summary, 'tags', COALESCE(( SELECT jsonb_agg(tag.tag ORDER BY tag.tag) AS jsonb_agg
           FROM public.article_tags tag
          WHERE ((tag.article_id)::text = (article.id)::text)), '[]'::jsonb), 'isFeatured', featured, 'relatedProducts', COALESCE(( SELECT jsonb_agg(related.product_id ORDER BY related.sort_order) AS jsonb_agg
           FROM public.article_related_products related
          WHERE ((related.article_id)::text = (article.id)::text)), '[]'::jsonb), 'content', COALESCE(( SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object('type', block.block_type, 'value', block.text_content, 'productId', block.product_id)) ORDER BY block.sort_order) AS jsonb_agg
           FROM public.article_content_blocks block
          WHERE ((block.article_id)::text = (article.id)::text)), '[]'::jsonb)) AS payload
   FROM public.articles article;


--
-- Name: booking_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_policies (
    id smallint NOT NULL,
    booking_window_days integer NOT NULL,
    advance_days integer NOT NULL,
    max_nights integer NOT NULL,
    timezone character varying(64) DEFAULT 'Asia/Taipei'::character varying NOT NULL,
    date_boundary_hour smallint DEFAULT 0 NOT NULL,
    low_availability_threshold integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_booking_policies_ranges CHECK (((booking_window_days > 0) AND (advance_days >= 0) AND (max_nights > 0) AND ((date_boundary_hour >= 0) AND (date_boundary_hour <= 23)) AND ((low_availability_threshold >= 0) AND (low_availability_threshold <= 100)))),
    CONSTRAINT ck_booking_policies_singleton CHECK ((id = 1)),
    CONSTRAINT ck_booking_policies_timezone CHECK (((timezone)::text = 'Asia/Taipei'::text))
);


--
-- Name: COLUMN booking_policies.low_availability_threshold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.booking_policies.low_availability_threshold IS 'Integer percent. Compatibility DTO divides by 100 to reproduce lowThresholdRatio.';


--
-- Name: booking_policy_availability_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_policy_availability_statuses (
    policy_id smallint NOT NULL,
    status character varying(24) NOT NULL,
    CONSTRAINT ck_booking_policy_availability_statuses_status CHECK ((btrim((status)::text) <> ''::text))
);


--
-- Name: booking_policy_occupying_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_policy_occupying_statuses (
    policy_id smallint NOT NULL,
    status character varying(24) NOT NULL,
    CONSTRAINT ck_booking_policy_occupying_statuses_status CHECK ((btrim((status)::text) <> ''::text))
);


--
-- Name: booking_selected_rentals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_selected_rentals (
    id bigint NOT NULL,
    booking_id character varying(32) NOT NULL,
    rental_listing_id character varying(64) NOT NULL,
    rental_sku_variant_id character varying(64) NOT NULL,
    sku_snapshot character varying(64) NOT NULL,
    name_snapshot character varying(200) NOT NULL,
    specification_snapshot character varying(200) NOT NULL,
    price_weekday_snapshot numeric(12,2) NOT NULL,
    price_holiday_snapshot numeric(12,2) NOT NULL,
    discount_snapshot numeric(12,2) NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT ck_booking_selected_rentals_money CHECK (((price_weekday_snapshot >= (0)::numeric) AND (price_holiday_snapshot >= (0)::numeric) AND (discount_snapshot >= (0)::numeric))),
    CONSTRAINT ck_booking_selected_rentals_quantity CHECK ((quantity > 0))
);


--
-- Name: booking_selected_rentals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.booking_selected_rentals ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.booking_selected_rentals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: booking_selected_zones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_selected_zones (
    id bigint NOT NULL,
    booking_id character varying(32) NOT NULL,
    zone_id character varying(32) NOT NULL,
    zone_type_snapshot character varying(64) NOT NULL,
    price_weekday_snapshot numeric(12,2) NOT NULL,
    price_holiday_snapshot numeric(12,2) NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT ck_booking_selected_zones_prices CHECK (((price_weekday_snapshot >= (0)::numeric) AND (price_holiday_snapshot >= (0)::numeric))),
    CONSTRAINT ck_booking_selected_zones_quantity CHECK ((quantity > 0))
);


--
-- Name: booking_selected_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.booking_selected_zones ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.booking_selected_zones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: booking_status_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.booking_status_history (
    id bigint NOT NULL,
    booking_id character varying(32) NOT NULL,
    status character varying(24) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    actor_id character varying(32),
    note text
);


--
-- Name: booking_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.booking_status_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.booking_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id character varying(32) NOT NULL,
    customer_id character varying(32) NOT NULL,
    campground_id character varying(32) NOT NULL,
    campground_name_snapshot character varying(150) NOT NULL,
    region_snapshot character varying(100) NOT NULL,
    check_in date NOT NULL,
    check_out date NOT NULL,
    guest_count integer NOT NULL,
    weekday_count integer NOT NULL,
    holiday_count integer NOT NULL,
    zone_total numeric(14,2) NOT NULL,
    rental_total numeric(14,2) NOT NULL,
    applied_discount numeric(14,2) NOT NULL,
    final_amount numeric(14,2) NOT NULL,
    status character varying(24) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_bookings_dates CHECK ((check_out > check_in)),
    CONSTRAINT ck_bookings_day_counts CHECK (((weekday_count >= 0) AND (holiday_count >= 0) AND ((weekday_count + holiday_count) = (check_out - check_in)))),
    CONSTRAINT ck_bookings_guests CHECK ((guest_count > 0)),
    CONSTRAINT ck_bookings_money CHECK (((zone_total >= (0)::numeric) AND (rental_total >= (0)::numeric) AND (applied_discount >= (0)::numeric) AND (final_amount = GREATEST(((zone_total + rental_total) - applied_discount), (0)::numeric))))
);


--
-- Name: branch_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_features (
    id bigint NOT NULL,
    branch_id character varying(32) NOT NULL,
    feature character varying(100) NOT NULL
);


--
-- Name: branch_features_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.branch_features_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: branch_features_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.branch_features_id_seq OWNED BY public.branch_features.id;


--
-- Name: branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branches (
    id character varying(32) NOT NULL,
    name character varying(120) NOT NULL,
    address character varying(300) NOT NULL,
    phone character varying(32) NOT NULL,
    latitude numeric(10,6),
    longitude numeric(10,6),
    map_query text,
    business_hours character varying(200) NOT NULL,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_branches_latitude CHECK (((latitude IS NULL) OR ((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric)))),
    CONSTRAINT ck_branches_longitude CHECK (((longitude IS NULL) OR ((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))))
);


--
-- Name: brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.brands (
    id character varying(32) NOT NULL,
    name character varying(120) NOT NULL,
    logo_url text,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_brands_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: calendar_dates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_dates (
    calendar_date date NOT NULL,
    is_holiday boolean NOT NULL,
    holiday_name character varying(120),
    source_version character varying(64) NOT NULL,
    effective_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_calendar_dates_holiday_name CHECK ((is_holiday OR (holiday_name IS NULL))),
    CONSTRAINT ck_calendar_dates_source CHECK ((btrim((source_version)::text) <> ''::text))
);


--
-- Name: campground_closures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campground_closures (
    id bigint NOT NULL,
    legacy_closure_id character varying(32) NOT NULL,
    campground_id character varying(32) NOT NULL,
    closure_type character varying(16) NOT NULL,
    start_date date,
    end_date date,
    weekday smallint,
    effective_from date,
    effective_to date,
    reason text NOT NULL,
    created_by character varying(32) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_campground_closures_payload CHECK (((((closure_type)::text = 'date_range'::text) AND (start_date IS NOT NULL) AND (end_date IS NOT NULL) AND (end_date >= start_date) AND (weekday IS NULL) AND (effective_from IS NULL) AND (effective_to IS NULL)) OR (((closure_type)::text = 'weekly'::text) AND (start_date IS NULL) AND (end_date IS NULL) AND ((weekday >= 0) AND (weekday <= 6)) AND (effective_from IS NOT NULL) AND (effective_to IS NOT NULL) AND (effective_to >= effective_from)))),
    CONSTRAINT ck_campground_closures_reason CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT ck_campground_closures_type CHECK (((closure_type)::text = ANY ((ARRAY['date_range'::character varying, 'weekly'::character varying])::text[])))
);


--
-- Name: COLUMN campground_closures.effective_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.campground_closures.effective_from IS 'Source-preserving inclusive lower bound for a weekly closure rule.';


--
-- Name: COLUMN campground_closures.effective_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.campground_closures.effective_to IS 'Source-preserving inclusive upper bound for a weekly closure rule.';


--
-- Name: campground_closures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.campground_closures ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.campground_closures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: campground_environment_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campground_environment_tags (
    campground_id character varying(32) NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: campground_facility_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campground_facility_tags (
    campground_id character varying(32) NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: campground_rental_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campground_rental_locations (
    campground_id character varying(32) NOT NULL,
    location_id character varying(32) NOT NULL
);


--
-- Name: campground_zones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campground_zones (
    id character varying(32) NOT NULL,
    campground_id character varying(32) NOT NULL,
    type character varying(64) NOT NULL,
    capacity_per_site integer DEFAULT 1 NOT NULL,
    price_weekday numeric(12,2) DEFAULT 0 NOT NULL,
    price_holiday numeric(12,2) DEFAULT 0 NOT NULL,
    total_sites integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_campground_zones_capacity CHECK ((capacity_per_site > 0)),
    CONSTRAINT ck_campground_zones_prices CHECK (((price_weekday >= (0)::numeric) AND (price_holiday >= (0)::numeric))),
    CONSTRAINT ck_campground_zones_sites CHECK ((total_sites > 0))
);


--
-- Name: TABLE campground_zones; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.campground_zones IS '營位區；total_sites 為每晚可賣上限 / Zones; total_sites = capacity ceiling';


--
-- Name: campgrounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campgrounds (
    id character varying(32) NOT NULL,
    name character varying(150) NOT NULL,
    region character varying(100) NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE campgrounds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.campgrounds IS '可預約營區 C002–C009（不含 C001 主倉）/ Bookable campgrounds only';


--
-- Name: coupon_usage_adjustments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupon_usage_adjustments (
    id bigint NOT NULL,
    order_coupon_id bigint NOT NULL,
    adjustment_type character varying(16) NOT NULL,
    quantity_delta smallint NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    reason text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_coupon_usage_adjustments_delta CHECK (((((adjustment_type)::text = 'restore'::text) AND (quantity_delta = '-1'::integer)) OR (((adjustment_type)::text = 'reconsume'::text) AND (quantity_delta = 1)))),
    CONSTRAINT ck_coupon_usage_adjustments_reason CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT ck_coupon_usage_adjustments_type CHECK (((adjustment_type)::text = ANY ((ARRAY['restore'::character varying, 'reconsume'::character varying])::text[])))
);


--
-- Name: coupon_usage_adjustments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.coupon_usage_adjustments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.coupon_usage_adjustments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupons (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(120) NOT NULL,
    discount_type character varying(16) NOT NULL,
    discount_value numeric(12,2) NOT NULL,
    minimum_amount numeric(12,2) DEFAULT 0 NOT NULL,
    issue_quantity integer NOT NULL,
    valid_from timestamp with time zone NOT NULL,
    valid_until timestamp with time zone NOT NULL,
    status character varying(16) NOT NULL,
    category character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_coupons_dates CHECK ((valid_until > valid_from)),
    CONSTRAINT ck_coupons_percentage CHECK ((((discount_type)::text <> 'percent'::text) OR (discount_value <= (100)::numeric))),
    CONSTRAINT ck_coupons_type CHECK (((discount_type)::text = ANY ((ARRAY['fixed'::character varying, 'percent'::character varying])::text[]))),
    CONSTRAINT ck_coupons_values CHECK (((discount_value > (0)::numeric) AND (minimum_amount >= (0)::numeric) AND (issue_quantity >= 0)))
);


--
-- Name: order_coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_coupons (
    id bigint NOT NULL,
    order_id character varying(32) NOT NULL,
    coupon_id bigint,
    code_snapshot character varying(64) NOT NULL,
    discount_type_snapshot character varying(16) NOT NULL,
    discount_value_snapshot numeric(12,2) NOT NULL,
    amount numeric(12,2) NOT NULL,
    applied_at timestamp with time zone NOT NULL,
    CONSTRAINT ck_order_coupons_amounts CHECK (((discount_value_snapshot >= (0)::numeric) AND (amount >= (0)::numeric)))
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id character varying(32) NOT NULL,
    customer_id character varying(32) NOT NULL,
    buyer_name_snapshot character varying(100) NOT NULL,
    buyer_email_snapshot character varying(254) NOT NULL,
    recipient_name_snapshot character varying(100) NOT NULL,
    shipping_address_snapshot text NOT NULL,
    shipping_phone_snapshot character varying(32) NOT NULL,
    subtotal numeric(14,2) NOT NULL,
    shipping_fee numeric(12,2) NOT NULL,
    discount numeric(14,2) NOT NULL,
    total numeric(14,2) NOT NULL,
    payment_method character varying(24) NOT NULL,
    payment_status character varying(24) NOT NULL,
    refund_status character varying(24) DEFAULT 'none'::character varying NOT NULL,
    status character varying(24) NOT NULL,
    placed_at timestamp with time zone NOT NULL,
    paid_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_orders_money CHECK (((subtotal >= (0)::numeric) AND (shipping_fee >= (0)::numeric) AND (discount >= (0)::numeric) AND (total = GREATEST(((subtotal + shipping_fee) - discount), (0)::numeric)))),
    CONSTRAINT ck_orders_payment_method CHECK (((payment_method)::text = ANY ((ARRAY['online'::character varying, 'cod'::character varying])::text[]))),
    CONSTRAINT ck_orders_status CHECK (((status)::text = ANY ((ARRAY['unshipped'::character varying, 'shipped'::character varying, 'completed'::character varying, 'cancelled'::character varying, 'returned'::character varying])::text[])))
);


--
-- Name: coupon_usage_stats; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.coupon_usage_stats AS
 WITH recognized AS (
         SELECT usage.coupon_id,
            count(*) AS quantity
           FROM (public.order_coupons usage
             JOIN public.orders orders ON (((orders.id)::text = (usage.order_id)::text)))
          WHERE ((usage.coupon_id IS NOT NULL) AND ((orders.payment_status)::text = 'paid'::text) AND ((orders.status)::text = ANY ((ARRAY['unshipped'::character varying, 'shipped'::character varying, 'completed'::character varying])::text[])))
          GROUP BY usage.coupon_id
        ), adjustments AS (
         SELECT usage.coupon_id,
            COALESCE(sum(adjustment.quantity_delta), (0)::bigint) AS quantity
           FROM (public.coupon_usage_adjustments adjustment
             JOIN public.order_coupons usage ON ((usage.id = adjustment.order_coupon_id)))
          WHERE (usage.coupon_id IS NOT NULL)
          GROUP BY usage.coupon_id
        )
 SELECT coupon.id AS coupon_id,
    (COALESCE(recognized.quantity, (0)::bigint) + COALESCE(adjustments.quantity, (0)::bigint)) AS used_quantity,
    ((coupon.issue_quantity - COALESCE(recognized.quantity, (0)::bigint)) - COALESCE(adjustments.quantity, (0)::bigint)) AS remaining_quantity
   FROM ((public.coupons coupon
     LEFT JOIN recognized ON ((recognized.coupon_id = coupon.id)))
     LEFT JOIN adjustments ON ((adjustments.coupon_id = coupon.id)));


--
-- Name: VIEW coupon_usage_stats; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.coupon_usage_stats IS 'P4 authoritative paid-order coupon use plus idempotent adjustment ledger; values are never silently clamped.';


--
-- Name: coupons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.coupons ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.coupons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: customer_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_preferences (
    customer_id character varying(32) NOT NULL,
    preference_id bigint NOT NULL
);


--
-- Name: customer_shipping_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_shipping_addresses (
    id bigint NOT NULL,
    customer_id character varying(32) NOT NULL,
    recipient_name character varying(100) NOT NULL,
    postal_code character varying(10) NOT NULL,
    city character varying(50) NOT NULL,
    district character varying(50) NOT NULL,
    address_line character varying(300) NOT NULL,
    phone character varying(32) NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: customer_shipping_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.customer_shipping_addresses ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.customer_shipping_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: customer_spending_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.customer_spending_summary AS
 SELECT customer_id,
    (sum(total))::numeric(14,2) AS total_spent
   FROM public.orders
  WHERE (((payment_status)::text = 'paid'::text) AND ((status)::text = 'completed'::text) AND ((refund_status)::text = 'none'::text))
  GROUP BY customer_id;


--
-- Name: VIEW customer_spending_summary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.customer_spending_summary IS 'P4 completed, paid and non-refunded order totals by customer.';


--
-- Name: customer_tag_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_tag_assignments (
    customer_id character varying(32) NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: customer_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_tags (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    color character varying(32) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_customer_tags_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: customer_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.customer_tags ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.customer_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: customer_tier_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.customer_tier_summary AS
 SELECT customer_id,
    total_spent,
    (
        CASE
            WHEN (total_spent >= (28000)::numeric) THEN 'master'::text
            WHEN (total_spent >= (12000)::numeric) THEN 'guide'::text
            ELSE 'explorer'::text
        END)::character varying(16) AS tier_code,
    (
        CASE
            WHEN (total_spent >= (28000)::numeric) THEN '大師'::text
            WHEN (total_spent >= (12000)::numeric) THEN '嚮導'::text
            ELSE '探險家'::text
        END)::character varying(32) AS tier_name
   FROM public.customer_spending_summary spending;


--
-- Name: VIEW customer_tier_summary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.customer_tier_summary IS 'P4 D-001 derived explorer/guide/master tier; never persisted to customer rows.';


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id character varying(32) DEFAULT replace((gen_random_uuid())::text, '-'::text, ''::text) NOT NULL,
    name character varying(100) NOT NULL,
    phone character varying(32),
    email character varying(255) NOT NULL,
    birthday date,
    registered_at timestamp with time zone NOT NULL,
    tier character varying(32),
    tier_name character varying(64),
    points integer DEFAULT 0 NOT NULL,
    first_purchase_used boolean DEFAULT false NOT NULL,
    auth_provider character varying(32) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    avatar_url text,
    active boolean DEFAULT true NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_customers_auth_provider CHECK (((auth_provider)::text = ANY ((ARRAY['google'::character varying, 'facebook'::character varying, 'line'::character varying])::text[]))),
    CONSTRAINT ck_customers_points CHECK ((points >= 0))
);


CREATE VIEW public.active_customers AS
 SELECT id,
    name,
    phone,
    email,
    birthday,
    registered_at,
    tier,
    tier_name,
    points,
    first_purchase_used,
    auth_provider,
    created_at,
    updated_at,
    avatar_url,
    active,
    deleted_at
   FROM public.customers
  WHERE ((active = true) AND (deleted_at IS NULL));


--
-- Name: TABLE customers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.customers IS '會員主檔 / Customers (OAuth only, no password). JSON: data/customers/customers.json';


--
-- Name: COLUMN customers.first_purchase_used; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.customers.first_purchase_used IS '是否已用過首購券資格 / firstPurchase coupon eligibility flag';


--
-- Name: environment_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.environment_tags (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    label character varying(100) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_environment_tags_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: environment_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.environment_tags ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.environment_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: equipment_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipment_images (
    item_id character varying(32) NOT NULL,
    sort_order integer NOT NULL,
    url text NOT NULL,
    alt_text character varying(200),
    CONSTRAINT ck_equipment_images_sort_order CHECK ((sort_order >= 0)),
    CONSTRAINT ck_equipment_images_value CHECK ((btrim(url) <> ''::text))
);


--
-- Name: equipment_interest_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipment_interest_tags (
    item_id character varying(32) NOT NULL,
    tag character varying(100) NOT NULL,
    CONSTRAINT ck_equipment_interest_tags_value CHECK ((btrim((tag)::text) <> ''::text))
);


--
-- Name: equipment_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipment_items (
    id character varying(32) NOT NULL,
    category_id bigint NOT NULL,
    brand_id character varying(32) NOT NULL,
    name character varying(200) NOT NULL,
    main_image_url text,
    description text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: equipment_specifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipment_specifications (
    item_id character varying(32) NOT NULL,
    spec_key character varying(100) NOT NULL,
    value text NOT NULL,
    CONSTRAINT ck_equipment_specifications_value CHECK ((btrim(value) <> ''::text))
);


--
-- Name: equipment_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipment_tags (
    item_id character varying(32) NOT NULL,
    tag character varying(100) NOT NULL,
    CONSTRAINT ck_equipment_tags_value CHECK ((btrim((tag)::text) <> ''::text))
);


--
-- Name: facility_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.facility_tags (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    label character varying(100) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_facility_tags_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: facility_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.facility_tags ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.facility_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inventory_conversions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_conversions (
    id bigint NOT NULL,
    source_movement_id bigint NOT NULL,
    destination_movement_id bigint NOT NULL,
    source_variant_id character varying(64) NOT NULL,
    destination_rental_variant_id character varying(64) NOT NULL,
    source_location_id character varying(32) NOT NULL,
    destination_location_id character varying(32) NOT NULL,
    quantity integer NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_inventory_conversions_different_movements CHECK ((source_movement_id <> destination_movement_id)),
    CONSTRAINT ck_inventory_conversions_quantity CHECK ((quantity > 0))
);


--
-- Name: inventory_conversions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.inventory_conversions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.inventory_conversions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inventory_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_locations (
    id character varying(32) NOT NULL,
    code character varying(32) NOT NULL,
    inventory_domain character varying(16) NOT NULL,
    type character varying(32) NOT NULL,
    branch_id character varying(32),
    name character varying(120) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_inventory_locations_branch_type CHECK (((((type)::text = 'branch'::text) AND ((inventory_domain)::text = 'store'::text) AND (branch_id IS NOT NULL)) OR (((type)::text <> 'branch'::text) AND (branch_id IS NULL)))),
    CONSTRAINT ck_inventory_locations_domain CHECK (((inventory_domain)::text = ANY ((ARRAY['store'::character varying, 'rental'::character varying])::text[]))),
    CONSTRAINT ck_inventory_locations_domain_type CHECK (((((inventory_domain)::text = 'store'::text) AND ((type)::text = ANY ((ARRAY['main'::character varying, 'branch'::character varying, 'inspection'::character varying, 'repair'::character varying, 'damaged'::character varying])::text[]))) OR (((inventory_domain)::text = 'rental'::text) AND ((type)::text = ANY ((ARRAY['main'::character varying, 'campground'::character varying, 'inspection'::character varying, 'repair'::character varying, 'damaged'::character varying])::text[]))))),
    CONSTRAINT ck_inventory_locations_type CHECK (((type)::text = ANY ((ARRAY['main'::character varying, 'branch'::character varying, 'campground'::character varying, 'inspection'::character varying, 'repair'::character varying, 'damaged'::character varying])::text[])))
);


--
-- Name: rental_inventory_movement_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_inventory_movement_items (
    id bigint NOT NULL,
    movement_id bigint NOT NULL,
    inventory_domain character varying(16) DEFAULT 'rental'::character varying NOT NULL,
    rental_sku_variant_id character varying(64) NOT NULL,
    sku_snapshot character varying(64) NOT NULL,
    item_name_snapshot character varying(200) NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT ck_rental_inventory_movement_items_domain CHECK (((inventory_domain)::text = 'rental'::text)),
    CONSTRAINT ck_rental_inventory_movement_items_quantity CHECK ((quantity > 0))
);


--
-- Name: store_inventory_movement_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_inventory_movement_items (
    id bigint NOT NULL,
    movement_id bigint NOT NULL,
    inventory_domain character varying(16) DEFAULT 'store'::character varying NOT NULL,
    variant_id character varying(64) NOT NULL,
    sku_snapshot character varying(64) NOT NULL,
    item_name_snapshot character varying(200) NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT ck_store_inventory_movement_items_domain CHECK (((inventory_domain)::text = 'store'::text)),
    CONSTRAINT ck_store_inventory_movement_items_quantity CHECK ((quantity > 0))
);


--
-- Name: inventory_movement_items_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.inventory_movement_items_view AS
 SELECT item.id,
    item.movement_id,
    item.inventory_domain,
    item.variant_id,
    item.sku_snapshot,
    item.item_name_snapshot,
    item.quantity
   FROM public.store_inventory_movement_items item
UNION ALL
 SELECT item.id,
    item.movement_id,
    item.inventory_domain,
    item.rental_sku_variant_id AS variant_id,
    item.sku_snapshot,
    item.item_name_snapshot,
    item.quantity
   FROM public.rental_inventory_movement_items item;


--
-- Name: VIEW inventory_movement_items_view; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.inventory_movement_items_view IS 'P5 read-only UNION ALL projection; application writes only concrete domain tables.';


--
-- Name: inventory_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_movements (
    id bigint NOT NULL,
    movement_no character varying(64) NOT NULL,
    legacy_movement_id character varying(64),
    inventory_domain character varying(16) NOT NULL,
    movement_type character varying(32) NOT NULL,
    status character varying(16) NOT NULL,
    source_location_id character varying(32),
    destination_location_id character varying(32),
    employee_id character varying(32) NOT NULL,
    reason text NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    posted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_inventory_movements_domain CHECK (((inventory_domain)::text = ANY ((ARRAY['store'::character varying, 'rental'::character varying])::text[]))),
    CONSTRAINT ck_inventory_movements_locations CHECK (((source_location_id IS NOT NULL) OR (destination_location_id IS NOT NULL))),
    CONSTRAINT ck_inventory_movements_posting CHECK (((((status)::text = 'posted'::text) AND (posted_at IS NOT NULL)) OR (((status)::text = ANY ((ARRAY['draft'::character varying, 'cancelled'::character varying])::text[])) AND (posted_at IS NULL)))),
    CONSTRAINT ck_inventory_movements_reason CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT ck_inventory_movements_status CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'posted'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT ck_inventory_movements_type CHECK ((btrim((movement_type)::text) <> ''::text)),
    CONSTRAINT ck_inventory_movements_type_payload CHECK (((((movement_type)::text = ANY ((ARRAY['進貨'::character varying, 'receipt'::character varying, 'adjustment_in'::character varying])::text[])) AND (source_location_id IS NULL) AND (destination_location_id IS NOT NULL)) OR (((movement_type)::text = ANY ((ARRAY['損耗'::character varying, 'write_off'::character varying, 'adjustment_out'::character varying])::text[])) AND (source_location_id IS NOT NULL) AND (destination_location_id IS NULL)) OR (((movement_type)::text = ANY ((ARRAY['移轉'::character varying, '營地互轉'::character varying, 'transfer'::character varying])::text[])) AND (source_location_id IS NOT NULL) AND (destination_location_id IS NOT NULL) AND ((source_location_id)::text <> (destination_location_id)::text)) OR (((movement_type)::text = 'conversion_out'::text) AND ((inventory_domain)::text = 'store'::text) AND (source_location_id IS NOT NULL) AND (destination_location_id IS NULL)) OR (((movement_type)::text = 'conversion_in'::text) AND ((inventory_domain)::text = 'rental'::text) AND (source_location_id IS NULL) AND (destination_location_id IS NOT NULL))))
);


--
-- Name: inventory_movement_dto_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.inventory_movement_dto_view AS
 SELECT id,
    jsonb_build_object('id', id, 'movementNo', movement_no, 'legacyMovementId', legacy_movement_id, 'inventoryDomain', inventory_domain, 'movementType', movement_type, 'status', status, 'sourceLocationId', source_location_id, 'destinationLocationId', destination_location_id, 'employeeId', employee_id, 'occurredAt', to_char((occurred_at AT TIME ZONE 'Asia/Taipei'::text), 'YYYY-MM-DD HH24:MI:SS'::text), 'items', COALESCE(( SELECT jsonb_agg(jsonb_build_object('inventoryDomain', item.inventory_domain, 'variantId', item.variant_id, 'sku', item.sku_snapshot, 'productName', item.item_name_snapshot, 'quantity', item.quantity, 'sourceLocationId', movement.source_location_id, 'destinationLocationId', movement.destination_location_id, 'type', movement.movement_type) ORDER BY item.id) AS jsonb_agg
           FROM public.inventory_movement_items_view item
          WHERE (item.movement_id = movement.id)), '[]'::jsonb)) AS payload
   FROM public.inventory_movements movement;


--
-- Name: VIEW inventory_movement_dto_view; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.inventory_movement_dto_view IS 'P6 admin/report DTO built exclusively from P5 inventory_movements and inventory_movement_items_view.';


--
-- Name: inventory_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.inventory_movements ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.inventory_movements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inventory_stocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_stocks (
    location_id character varying(32) NOT NULL,
    variant_id character varying(64) NOT NULL,
    on_hand_quantity integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_inventory_stocks_on_hand CHECK ((on_hand_quantity >= 0))
);


--
-- Name: legacy_review_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_review_photos (
    legacy_review_id character varying(32) NOT NULL,
    sort_order integer NOT NULL,
    url text NOT NULL,
    CONSTRAINT ck_legacy_review_photos_sort_order CHECK ((sort_order >= 0)),
    CONSTRAINT ck_legacy_review_photos_url CHECK ((btrim(url) <> ''::text))
);


--
-- Name: legacy_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.legacy_reviews (
    id character varying(32) NOT NULL,
    customer_id character varying(32) NOT NULL,
    product_id character varying(32) NOT NULL,
    variant_id character varying(64) NOT NULL,
    sku_snapshot character varying(64),
    buyer_name_snapshot character varying(100),
    buyer_avatar_snapshot text,
    product_name_snapshot character varying(200),
    rating smallint NOT NULL,
    comment text,
    created_at timestamp with time zone NOT NULL,
    legacy_reason text NOT NULL,
    CONSTRAINT ck_legacy_reviews_rating CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT ck_legacy_reviews_reason CHECK ((btrim(legacy_reason) <> ''::text))
);


--
-- Name: TABLE legacy_reviews; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.legacy_reviews IS 'Read-only reviews without a uniquely provable order item; never writable through the formal review API.';


--
-- Name: order_coupons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.order_coupons ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_coupons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id character varying(32) NOT NULL,
    product_id character varying(32) NOT NULL,
    variant_id character varying(64) NOT NULL,
    sku_snapshot character varying(64) NOT NULL,
    product_name_snapshot character varying(200) NOT NULL,
    specification_snapshot character varying(200) NOT NULL,
    brand_name_snapshot character varying(120) NOT NULL,
    image_url_snapshot text,
    unit_price_snapshot numeric(12,2) NOT NULL,
    quantity integer NOT NULL,
    CONSTRAINT ck_order_items_price CHECK ((unit_price_snapshot >= (0)::numeric)),
    CONSTRAINT ck_order_items_quantity CHECK ((quantity > 0))
);


--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.order_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: order_status_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_status_history (
    id bigint NOT NULL,
    order_id character varying(32) NOT NULL,
    status character varying(24) NOT NULL,
    occurred_at timestamp with time zone NOT NULL,
    actor_id character varying(32),
    note text
);


--
-- Name: order_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.order_status_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: preference_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.preference_options (
    id bigint NOT NULL,
    type character varying(32) NOT NULL,
    code character varying(64) NOT NULL,
    label character varying(100) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_preference_options_sort_order CHECK ((sort_order >= 0)),
    CONSTRAINT ck_preference_options_type CHECK (((type)::text = ANY ((ARRAY['style'::character varying, 'equipment'::character varying])::text[])))
);


--
-- Name: preference_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.preference_options ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.preference_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: product_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_categories (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(100) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_product_categories_sort_order CHECK ((sort_order >= 0))
);


--
-- Name: product_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.product_categories ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.product_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: product_stock_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_stock_reservations (
    id bigint NOT NULL,
    order_item_id bigint NOT NULL,
    variant_id character varying(64) NOT NULL,
    location_id character varying(32) NOT NULL,
    quantity integer NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    reserved_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    released_at timestamp with time zone,
    fulfilled_at timestamp with time zone,
    inventory_domain character varying(16) DEFAULT 'store'::character varying NOT NULL,
    CONSTRAINT ck_product_stock_reservations_domain CHECK (((inventory_domain)::text = 'store'::text)),
    CONSTRAINT ck_product_stock_reservations_expiry CHECK (((expires_at IS NULL) OR (expires_at > reserved_at))),
    CONSTRAINT ck_product_stock_reservations_quantity CHECK ((quantity > 0)),
    CONSTRAINT ck_product_stock_reservations_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'released'::character varying, 'fulfilled'::character varying, 'expired'::character varying])::text[]))),
    CONSTRAINT ck_product_stock_reservations_terminal CHECK (((((status)::text = 'active'::text) AND (released_at IS NULL) AND (fulfilled_at IS NULL)) OR (((status)::text = ANY ((ARRAY['released'::character varying, 'expired'::character varying])::text[])) AND (released_at IS NOT NULL) AND (fulfilled_at IS NULL)) OR (((status)::text = 'fulfilled'::text) AND (fulfilled_at IS NOT NULL))))
);


--
-- Name: product_stock_reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.product_stock_reservations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.product_stock_reservations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: product_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_variants (
    id character varying(64) NOT NULL,
    product_id character varying(32) NOT NULL,
    sku character varying(64) NOT NULL,
    color character varying(100),
    size character varying(100),
    price numeric(12,2) NOT NULL,
    specification character varying(200) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_product_variants_price CHECK ((price >= (0)::numeric)),
    CONSTRAINT ck_product_variants_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: TABLE product_variants; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_variants IS '商品 SKU / Product variants. JSON: products.json > variants[]';


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id character varying(32) NOT NULL,
    price numeric(12,2) DEFAULT 0 NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    item_id character varying(32) NOT NULL,
    CONSTRAINT ck_products_price CHECK ((price >= (0)::numeric)),
    CONSTRAINT ck_products_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: TABLE products; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.products IS '商城商品 SPU / Store products. JSON: data/catalog/products.json';


--
-- Name: product_stock_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.product_stock_summary AS
 WITH stock AS (
         SELECT variant.product_id,
            COALESCE(sum(inventory.on_hand_quantity), (0)::bigint) AS total_on_hand
           FROM (public.product_variants variant
             LEFT JOIN public.inventory_stocks inventory ON (((inventory.variant_id)::text = (variant.id)::text)))
          GROUP BY variant.product_id
        ), reserved AS (
         SELECT variant.product_id,
            COALESCE(sum(reservation.quantity), (0)::bigint) AS total_reserved
           FROM (public.product_stock_reservations reservation
             JOIN public.product_variants variant ON (((variant.id)::text = (reservation.variant_id)::text)))
          WHERE ((reservation.status)::text = 'active'::text)
          GROUP BY variant.product_id
        )
 SELECT product.id AS product_id,
    COALESCE(stock.total_on_hand, (0)::bigint) AS total_on_hand,
    COALESCE(reserved.total_reserved, (0)::bigint) AS total_reserved,
    (COALESCE(stock.total_on_hand, (0)::bigint) - COALESCE(reserved.total_reserved, (0)::bigint)) AS total_available
   FROM ((public.products product
     LEFT JOIN stock ON (((stock.product_id)::text = (product.id)::text)))
     LEFT JOIN reserved ON (((reserved.product_id)::text = (product.id)::text)));


--
-- Name: VIEW product_stock_summary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.product_stock_summary IS 'P4 physical product stock minus active product reservation ledger.';


--
-- Name: product_variant_min_stocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_variant_min_stocks (
    variant_id character varying(64) NOT NULL,
    location_id character varying(32) NOT NULL,
    minimum_quantity integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_product_variant_min_stocks_quantity CHECK ((minimum_quantity >= 0))
);


--
-- Name: rental_inventory_movement_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.rental_inventory_movement_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.rental_inventory_movement_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: rental_listings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_listings (
    id character varying(64) NOT NULL,
    campground_id character varying(32) NOT NULL,
    rental_sku_variant_id character varying(64) NOT NULL,
    price_per_day_weekday numeric(12,2) NOT NULL,
    price_per_day_holiday numeric(12,2) NOT NULL,
    discount numeric(12,2) DEFAULT 0 NOT NULL,
    terrain character varying(100),
    description text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_rental_listings_prices CHECK (((price_per_day_weekday >= (0)::numeric) AND (price_per_day_holiday >= (0)::numeric) AND (discount >= (0)::numeric)))
);


--
-- Name: rental_sku_variant_stocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_sku_variant_stocks (
    location_id character varying(32) NOT NULL,
    rental_sku_variant_id character varying(64) NOT NULL,
    on_hand_quantity integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_rental_sku_variant_stocks_on_hand CHECK ((on_hand_quantity >= 0))
);


--
-- Name: rental_listing_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rental_listing_view AS
 SELECT listing.id,
    listing.campground_id,
    listing.rental_sku_variant_id,
    mapping.location_id,
    listing.price_per_day_weekday,
    listing.price_per_day_holiday,
    listing.discount,
    COALESCE(stock.on_hand_quantity, 0) AS stock
   FROM ((public.rental_listings listing
     JOIN public.campground_rental_locations mapping ON (((mapping.campground_id)::text = (listing.campground_id)::text)))
     LEFT JOIN public.rental_sku_variant_stocks stock ON ((((stock.location_id)::text = (mapping.location_id)::text) AND ((stock.rental_sku_variant_id)::text = (listing.rental_sku_variant_id)::text))));


--
-- Name: VIEW rental_listing_view; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.rental_listing_view IS 'P3 read-only listing/location/physical-stock projection; reservation availability belongs to P4.';


--
-- Name: rental_sku_variant_min_stocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_sku_variant_min_stocks (
    rental_sku_variant_id character varying(64) NOT NULL,
    location_id character varying(32) NOT NULL,
    minimum_quantity integer NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_rental_sku_variant_min_stocks_quantity CHECK ((minimum_quantity >= 0))
);


--
-- Name: rental_sku_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_sku_variants (
    id character varying(64) NOT NULL,
    rental_sku_id character varying(32) NOT NULL,
    sku character varying(64) NOT NULL,
    color character varying(100),
    size character varying(100),
    specification character varying(200) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_rental_sku_variants_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: rental_skus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_skus (
    id character varying(32) NOT NULL,
    item_id character varying(32) NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_rental_skus_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying])::text[])))
);


--
-- Name: TABLE rental_skus; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.rental_skus IS '租借 SKU 群組＝庫存唯一寫入來源 / Rental stock authority. JSON: data/admin/rental-skus.json';


--
-- Name: rental_stock_reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_stock_reservations (
    id bigint NOT NULL,
    booking_selected_rental_id bigint NOT NULL,
    rental_sku_variant_id character varying(64) NOT NULL,
    location_id character varying(32) NOT NULL,
    check_in date NOT NULL,
    check_out date NOT NULL,
    quantity integer NOT NULL,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    idempotency_key character varying(128) NOT NULL,
    reserved_at timestamp with time zone DEFAULT now() NOT NULL,
    released_at timestamp with time zone,
    fulfilled_at timestamp with time zone,
    inventory_domain character varying(16) DEFAULT 'rental'::character varying NOT NULL,
    CONSTRAINT ck_rental_stock_reservations_dates CHECK ((check_out > check_in)),
    CONSTRAINT ck_rental_stock_reservations_domain CHECK (((inventory_domain)::text = 'rental'::text)),
    CONSTRAINT ck_rental_stock_reservations_quantity CHECK ((quantity > 0)),
    CONSTRAINT ck_rental_stock_reservations_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'released'::character varying, 'fulfilled'::character varying])::text[]))),
    CONSTRAINT ck_rental_stock_reservations_terminal CHECK (((((status)::text = 'active'::text) AND (released_at IS NULL) AND (fulfilled_at IS NULL)) OR (((status)::text = 'released'::text) AND (released_at IS NOT NULL) AND (fulfilled_at IS NULL)) OR (((status)::text = 'fulfilled'::text) AND (fulfilled_at IS NOT NULL))))
);


--
-- Name: rental_stock_reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.rental_stock_reservations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.rental_stock_reservations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: review_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_photos (
    review_id character varying(32) NOT NULL,
    sort_order integer NOT NULL,
    url text NOT NULL,
    CONSTRAINT ck_review_photos_sort_order CHECK ((sort_order >= 0)),
    CONSTRAINT ck_review_photos_url CHECK ((btrim(url) <> ''::text))
);


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id character varying(32) NOT NULL,
    order_item_id bigint NOT NULL,
    rating smallint NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_reviews_rating CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: TABLE reviews; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.reviews IS 'Formal verified-purchase reviews; order_item_id is the only authoritative relationship.';


--
-- Name: review_dto_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.review_dto_view AS
 SELECT review.id,
    true AS verified_purchase,
    jsonb_build_object('id', review.id, 'customerId', order_header.customer_id, 'productId', item.product_id, 'variantId', item.variant_id, 'sku', item.sku_snapshot, 'orderId', item.order_id, 'orderItemId', review.order_item_id, 'buyerName', order_header.buyer_name_snapshot, 'buyerAvatar', customer.avatar_url, 'productName', item.product_name_snapshot, 'rating', review.rating, 'comment', review.comment, 'photos', COALESCE(( SELECT jsonb_agg(photo.url ORDER BY photo.sort_order) AS jsonb_agg
           FROM public.review_photos photo
          WHERE ((photo.review_id)::text = (review.id)::text)), '[]'::jsonb), 'createdAt', to_char((review.created_at AT TIME ZONE 'Asia/Taipei'::text), 'YYYY-MM-DD HH24:MI:SS'::text), 'verifiedPurchase', true) AS payload
   FROM (((public.reviews review
     JOIN public.order_items item ON ((item.id = review.order_item_id)))
     JOIN public.orders order_header ON (((order_header.id)::text = (item.order_id)::text)))
     JOIN public.customers customer ON (((customer.id)::text = (order_header.customer_id)::text)))
UNION ALL
 SELECT review.id,
    false AS verified_purchase,
    jsonb_build_object('id', review.id, 'customerId', review.customer_id, 'productId', review.product_id, 'variantId', review.variant_id, 'sku', review.sku_snapshot, 'buyerName', review.buyer_name_snapshot, 'buyerAvatar', review.buyer_avatar_snapshot, 'productName', review.product_name_snapshot, 'rating', review.rating, 'comment', review.comment, 'photos', COALESCE(( SELECT jsonb_agg(photo.url ORDER BY photo.sort_order) AS jsonb_agg
           FROM public.legacy_review_photos photo
          WHERE ((photo.legacy_review_id)::text = (review.id)::text)), '[]'::jsonb), 'createdAt', to_char((review.created_at AT TIME ZONE 'Asia/Taipei'::text), 'YYYY-MM-DD HH24:MI:SS'::text), 'verifiedPurchase', false) AS payload
   FROM public.legacy_reviews review;


--
-- Name: store_inventory_movement_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.store_inventory_movement_items ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.store_inventory_movement_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: zone_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zone_blocks (
    id bigint NOT NULL,
    legacy_block_id character varying(32) NOT NULL,
    campground_id character varying(32) NOT NULL,
    zone_id character varying(32) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    blocked_quantity integer NOT NULL,
    reason text NOT NULL,
    created_by character varying(32) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_zone_blocks_dates CHECK ((end_date >= start_date)),
    CONSTRAINT ck_zone_blocks_quantity CHECK ((blocked_quantity > 0)),
    CONSTRAINT ck_zone_blocks_reason CHECK ((btrim(reason) <> ''::text))
);


--
-- Name: zone_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.zone_blocks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.zone_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: p3_legacy_rental_sku_variant_stocks id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_sku_variant_stocks ALTER COLUMN id SET DEFAULT nextval('migration.p3_legacy_rental_sku_variant_stocks_id_seq'::regclass);


--
-- Name: p4_legacy_booking_history id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_history ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_booking_history_id_seq'::regclass);


--
-- Name: p4_legacy_booking_selected_rentals id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_booking_selected_rentals_id_seq'::regclass);


--
-- Name: p4_legacy_booking_selected_zones id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_zones ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_booking_selected_zones_id_seq'::regclass);


--
-- Name: p4_legacy_bookings id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_bookings ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_bookings_id_seq'::regclass);


--
-- Name: p4_legacy_order_coupons id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_coupons ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_order_coupons_id_seq'::regclass);


--
-- Name: p4_legacy_order_history id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_history ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_order_history_id_seq'::regclass);


--
-- Name: p4_legacy_order_items id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_items ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_order_items_id_seq'::regclass);


--
-- Name: p4_legacy_orders id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_orders ALTER COLUMN id SET DEFAULT nextval('migration.p4_legacy_orders_id_seq'::regclass);


--
-- Name: p5_legacy_booking_policies id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_booking_policies ALTER COLUMN id SET DEFAULT nextval('migration.p5_legacy_booking_policies_id_seq'::regclass);


--
-- Name: p5_legacy_min_stocks id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_min_stocks ALTER COLUMN id SET DEFAULT nextval('migration.p5_legacy_min_stocks_id_seq'::regclass);


--
-- Name: p5_legacy_movement_items id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movement_items ALTER COLUMN id SET DEFAULT nextval('migration.p5_legacy_movement_items_id_seq'::regclass);


--
-- Name: p5_legacy_movements id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movements ALTER COLUMN id SET DEFAULT nextval('migration.p5_legacy_movements_id_seq'::regclass);


--
-- Name: p6_legacy_article_content_blocks id; Type: DEFAULT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_content_blocks ALTER COLUMN id SET DEFAULT nextval('migration.p6_legacy_article_content_blocks_id_seq'::regclass);


--
-- Name: branch_features id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_features ALTER COLUMN id SET DEFAULT nextval('public.branch_features_id_seq'::regclass);


--
-- Name: p6_legacy_article_content_blocks article_content_blocks_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_content_blocks
    ADD CONSTRAINT article_content_blocks_pkey PRIMARY KEY (id);


--
-- Name: p6_legacy_article_related_products article_related_products_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_related_products
    ADD CONSTRAINT article_related_products_pkey PRIMARY KEY (article_id, product_id);


--
-- Name: p6_legacy_articles articles_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_booking_history booking_history_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_history
    ADD CONSTRAINT booking_history_pkey PRIMARY KEY (id);


--
-- Name: p5_legacy_booking_policies booking_policies_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_booking_policies
    ADD CONSTRAINT booking_policies_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_booking_selected_rentals booking_selected_rentals_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals
    ADD CONSTRAINT booking_selected_rentals_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_booking_selected_zones booking_selected_zones_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_zones
    ADD CONSTRAINT booking_selected_zones_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_bookings bookings_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: p5_legacy_campground_closures campground_closures_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_campground_closures
    ADD CONSTRAINT campground_closures_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_coupons coupons_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_coupons
    ADD CONSTRAINT coupons_pkey PRIMARY KEY (code);


--
-- Name: p5_legacy_min_stocks min_stocks_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_min_stocks
    ADD CONSTRAINT min_stocks_pkey PRIMARY KEY (id);


--
-- Name: p5_legacy_min_stocks min_stocks_target_type_target_id_location_key_key; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_min_stocks
    ADD CONSTRAINT min_stocks_target_type_target_id_location_key_key UNIQUE (target_type, target_id, location_key);


--
-- Name: p5_legacy_movement_items movement_items_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movement_items
    ADD CONSTRAINT movement_items_pkey PRIMARY KEY (id);


--
-- Name: p5_legacy_movements movements_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movements
    ADD CONSTRAINT movements_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_order_coupons order_coupons_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_coupons
    ADD CONSTRAINT order_coupons_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_order_history order_history_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_history
    ADD CONSTRAINT order_history_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_order_items order_items_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: p4_legacy_orders orders_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: p4_action_map p4_action_map_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_action_map
    ADD CONSTRAINT p4_action_map_pkey PRIMARY KEY (domain, legacy_action);


--
-- Name: p4_booking_day_count_resolution p4_booking_day_count_resolution_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_booking_day_count_resolution
    ADD CONSTRAINT p4_booking_day_count_resolution_pkey PRIMARY KEY (booking_id);


--
-- Name: p4_booking_source p4_booking_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_booking_source
    ADD CONSTRAINT p4_booking_source_pkey PRIMARY KEY (id);


--
-- Name: p4_coupon_source p4_coupon_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_coupon_source
    ADD CONSTRAINT p4_coupon_source_pkey PRIMARY KEY (code);


--
-- Name: p4_order_source p4_order_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_order_source
    ADD CONSTRAINT p4_order_source_pkey PRIMARY KEY (id);


--
-- Name: p4_rental_price_reconciliation p4_rental_price_reconciliation_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_rental_price_reconciliation
    ADD CONSTRAINT p4_rental_price_reconciliation_pkey PRIMARY KEY (booking_id, rental_ordinal);


--
-- Name: p4_rental_reservation_quarantine p4_rental_reservation_quarantine_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_rental_reservation_quarantine
    ADD CONSTRAINT p4_rental_reservation_quarantine_pkey PRIMARY KEY (booking_id, rental_ordinal);


--
-- Name: p4_snapshot_fallbacks p4_snapshot_fallbacks_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_snapshot_fallbacks
    ADD CONSTRAINT p4_snapshot_fallbacks_pkey PRIMARY KEY (domain, source_id, field_name);


--
-- Name: p4_zone_price_reconciliation p4_zone_price_reconciliation_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_zone_price_reconciliation
    ADD CONSTRAINT p4_zone_price_reconciliation_pkey PRIMARY KEY (booking_id, zone_ordinal);


--
-- Name: p5_closure_source p5_closure_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_closure_source
    ADD CONSTRAINT p5_closure_source_pkey PRIMARY KEY (legacy_id);


--
-- Name: p5_location_resolution p5_location_resolution_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_location_resolution
    ADD CONSTRAINT p5_location_resolution_pkey PRIMARY KEY (legacy_label);


--
-- Name: p5_min_stock_source p5_min_stock_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_min_stock_source
    ADD CONSTRAINT p5_min_stock_source_pkey PRIMARY KEY (inventory_domain, target_id, location_id);


--
-- Name: p5_movement_source p5_movement_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_movement_source
    ADD CONSTRAINT p5_movement_source_pkey PRIMARY KEY (legacy_movement_id);


--
-- Name: p5_policy_source p5_policy_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_policy_source
    ADD CONSTRAINT p5_policy_source_pkey PRIMARY KEY (id);


--
-- Name: p5_variant_resolution p5_variant_resolution_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_variant_resolution
    ADD CONSTRAINT p5_variant_resolution_pkey PRIMARY KEY (legacy_movement_id, legacy_item_ordinal);


--
-- Name: p5_zone_block_source p5_zone_block_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_zone_block_source
    ADD CONSTRAINT p5_zone_block_source_pkey PRIMARY KEY (legacy_id);


--
-- Name: p6_article_source p6_article_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_article_source
    ADD CONSTRAINT p6_article_source_pkey PRIMARY KEY (id);


--
-- Name: p6_review_resolution p6_review_resolution_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_review_resolution
    ADD CONSTRAINT p6_review_resolution_pkey PRIMARY KEY (review_id);


--
-- Name: p6_review_source p6_review_source_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_review_source
    ADD CONSTRAINT p6_review_source_pkey PRIMARY KEY (id);


--
-- Name: movement_migration_map pk_movement_migration_map; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.movement_migration_map
    ADD CONSTRAINT pk_movement_migration_map PRIMARY KEY (legacy_movement_id, legacy_item_ordinal);


--
-- Name: p1_location_aliases pk_p1_location_aliases; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p1_location_aliases
    ADD CONSTRAINT pk_p1_location_aliases PRIMARY KEY (alias);


--
-- Name: p1_location_quarantine pk_p1_location_quarantine; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p1_location_quarantine
    ADD CONSTRAINT pk_p1_location_quarantine PRIMARY KEY (source_table, source_row_id, field_name, raw_value);


--
-- Name: p2_campground_tag_source pk_p2_campground_tag_source; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p2_campground_tag_source
    ADD CONSTRAINT pk_p2_campground_tag_source PRIMARY KEY (campground_id);


--
-- Name: p2_product_source pk_p2_product_source; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p2_product_source
    ADD CONSTRAINT pk_p2_product_source PRIMARY KEY (product_id);


--
-- Name: p3_listing_source pk_p3_listing_source; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_listing_source
    ADD CONSTRAINT pk_p3_listing_source PRIMARY KEY (listing_id);


--
-- Name: p3_rental_min_stock_source pk_p3_rental_min_stock_source; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_rental_min_stock_source
    ADD CONSTRAINT pk_p3_rental_min_stock_source PRIMARY KEY (rental_sku_id, location_id);


--
-- Name: p3_rental_sku_source pk_p3_rental_sku_source; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_rental_sku_source
    ADD CONSTRAINT pk_p3_rental_sku_source PRIMARY KEY (rental_sku_id);


--
-- Name: p3_rental_variant_map pk_p3_rental_variant_map; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_rental_variant_map
    ADD CONSTRAINT pk_p3_rental_variant_map PRIMARY KEY (rental_sku_id, legacy_variant_id);


--
-- Name: p7_contract_evidence pk_p7_contract_evidence; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p7_contract_evidence
    ADD CONSTRAINT pk_p7_contract_evidence PRIMARY KEY (id);


--
-- Name: p3_legacy_rental_listings rental_listings_campground_id_variant_id_key; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_listings
    ADD CONSTRAINT rental_listings_campground_id_variant_id_key UNIQUE (campground_id, variant_id);


--
-- Name: p3_legacy_rental_listings rental_listings_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_listings
    ADD CONSTRAINT rental_listings_pkey PRIMARY KEY (id);


--
-- Name: p3_legacy_rental_sku_variant_stocks rental_sku_variant_stocks_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_sku_variant_stocks
    ADD CONSTRAINT rental_sku_variant_stocks_pkey PRIMARY KEY (id);


--
-- Name: p3_legacy_rental_sku_variant_stocks rental_sku_variant_stocks_rental_sku_id_variant_id_campgrou_key; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_sku_variant_stocks
    ADD CONSTRAINT rental_sku_variant_stocks_rental_sku_id_variant_id_campgrou_key UNIQUE (rental_sku_id, variant_id, campground_id);


--
-- Name: p6_legacy_reviews reviews_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: p3_rental_variant_map uq_p3_rental_variant_map_target; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_rental_variant_map
    ADD CONSTRAINT uq_p3_rental_variant_map_target UNIQUE (rental_variant_id);


--
-- Name: p5_legacy_zone_blocks zone_blocks_pkey; Type: CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_zone_blocks
    ADD CONSTRAINT zone_blocks_pkey PRIMARY KEY (id);


--
-- Name: admin_users pk_admin_users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT pk_admin_users PRIMARY KEY (id);


--
-- Name: article_content_blocks pk_article_content_blocks; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_content_blocks
    ADD CONSTRAINT pk_article_content_blocks PRIMARY KEY (id);


--
-- Name: article_related_products pk_article_related_products; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_related_products
    ADD CONSTRAINT pk_article_related_products PRIMARY KEY (article_id, product_id);


--
-- Name: article_tags pk_article_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_tags
    ADD CONSTRAINT pk_article_tags PRIMARY KEY (article_id, tag);


--
-- Name: articles pk_articles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT pk_articles PRIMARY KEY (id);


--
-- Name: booking_policies pk_booking_policies; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_policies
    ADD CONSTRAINT pk_booking_policies PRIMARY KEY (id);


--
-- Name: booking_policy_availability_statuses pk_booking_policy_availability_statuses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_policy_availability_statuses
    ADD CONSTRAINT pk_booking_policy_availability_statuses PRIMARY KEY (policy_id, status);


--
-- Name: booking_policy_occupying_statuses pk_booking_policy_occupying_statuses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_policy_occupying_statuses
    ADD CONSTRAINT pk_booking_policy_occupying_statuses PRIMARY KEY (policy_id, status);


--
-- Name: booking_selected_rentals pk_booking_selected_rentals; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_rentals
    ADD CONSTRAINT pk_booking_selected_rentals PRIMARY KEY (id);


--
-- Name: booking_selected_zones pk_booking_selected_zones; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_zones
    ADD CONSTRAINT pk_booking_selected_zones PRIMARY KEY (id);


--
-- Name: booking_status_history pk_booking_status_history; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_status_history
    ADD CONSTRAINT pk_booking_status_history PRIMARY KEY (id);


--
-- Name: bookings pk_bookings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT pk_bookings PRIMARY KEY (id);


--
-- Name: branch_features pk_branch_features; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_features
    ADD CONSTRAINT pk_branch_features PRIMARY KEY (id);


--
-- Name: branches pk_branches; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT pk_branches PRIMARY KEY (id);


--
-- Name: brands pk_brands; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT pk_brands PRIMARY KEY (id);


--
-- Name: calendar_dates pk_calendar_dates; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_dates
    ADD CONSTRAINT pk_calendar_dates PRIMARY KEY (calendar_date);


--
-- Name: campground_closures pk_campground_closures; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_closures
    ADD CONSTRAINT pk_campground_closures PRIMARY KEY (id);


--
-- Name: campground_environment_tags pk_campground_environment_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_environment_tags
    ADD CONSTRAINT pk_campground_environment_tags PRIMARY KEY (campground_id, tag_id);


--
-- Name: campground_facility_tags pk_campground_facility_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_facility_tags
    ADD CONSTRAINT pk_campground_facility_tags PRIMARY KEY (campground_id, tag_id);


--
-- Name: campground_rental_locations pk_campground_rental_locations; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_rental_locations
    ADD CONSTRAINT pk_campground_rental_locations PRIMARY KEY (campground_id);


--
-- Name: campground_zones pk_campground_zones; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_zones
    ADD CONSTRAINT pk_campground_zones PRIMARY KEY (id);


--
-- Name: campgrounds pk_campgrounds; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campgrounds
    ADD CONSTRAINT pk_campgrounds PRIMARY KEY (id);


--
-- Name: coupon_usage_adjustments pk_coupon_usage_adjustments; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_usage_adjustments
    ADD CONSTRAINT pk_coupon_usage_adjustments PRIMARY KEY (id);


--
-- Name: coupons pk_coupons; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT pk_coupons PRIMARY KEY (id);


--
-- Name: customer_preferences pk_customer_preferences; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_preferences
    ADD CONSTRAINT pk_customer_preferences PRIMARY KEY (customer_id, preference_id);


--
-- Name: customer_shipping_addresses pk_customer_shipping_addresses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_shipping_addresses
    ADD CONSTRAINT pk_customer_shipping_addresses PRIMARY KEY (id);


--
-- Name: customer_tag_assignments pk_customer_tag_assignments; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_tag_assignments
    ADD CONSTRAINT pk_customer_tag_assignments PRIMARY KEY (customer_id, tag_id);


--
-- Name: customer_tags pk_customer_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_tags
    ADD CONSTRAINT pk_customer_tags PRIMARY KEY (id);


--
-- Name: customers pk_customers; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT pk_customers PRIMARY KEY (id);


--
-- Name: environment_tags pk_environment_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.environment_tags
    ADD CONSTRAINT pk_environment_tags PRIMARY KEY (id);


--
-- Name: equipment_images pk_equipment_images; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_images
    ADD CONSTRAINT pk_equipment_images PRIMARY KEY (item_id, sort_order);


--
-- Name: equipment_interest_tags pk_equipment_interest_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_interest_tags
    ADD CONSTRAINT pk_equipment_interest_tags PRIMARY KEY (item_id, tag);


--
-- Name: equipment_items pk_equipment_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_items
    ADD CONSTRAINT pk_equipment_items PRIMARY KEY (id);


--
-- Name: equipment_specifications pk_equipment_specifications; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_specifications
    ADD CONSTRAINT pk_equipment_specifications PRIMARY KEY (item_id, spec_key);


--
-- Name: equipment_tags pk_equipment_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_tags
    ADD CONSTRAINT pk_equipment_tags PRIMARY KEY (item_id, tag);


--
-- Name: facility_tags pk_facility_tags; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_tags
    ADD CONSTRAINT pk_facility_tags PRIMARY KEY (id);


--
-- Name: inventory_conversions pk_inventory_conversions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT pk_inventory_conversions PRIMARY KEY (id);


--
-- Name: inventory_locations pk_inventory_locations; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_locations
    ADD CONSTRAINT pk_inventory_locations PRIMARY KEY (id);


--
-- Name: inventory_movements pk_inventory_movements; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_movements
    ADD CONSTRAINT pk_inventory_movements PRIMARY KEY (id);


--
-- Name: inventory_stocks pk_inventory_stocks; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_stocks
    ADD CONSTRAINT pk_inventory_stocks PRIMARY KEY (location_id, variant_id);


--
-- Name: legacy_review_photos pk_legacy_review_photos; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_review_photos
    ADD CONSTRAINT pk_legacy_review_photos PRIMARY KEY (legacy_review_id, sort_order);


--
-- Name: legacy_reviews pk_legacy_reviews; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_reviews
    ADD CONSTRAINT pk_legacy_reviews PRIMARY KEY (id);


--
-- Name: order_coupons pk_order_coupons; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_coupons
    ADD CONSTRAINT pk_order_coupons PRIMARY KEY (id);


--
-- Name: order_items pk_order_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT pk_order_items PRIMARY KEY (id);


--
-- Name: order_status_history pk_order_status_history; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT pk_order_status_history PRIMARY KEY (id);


--
-- Name: orders pk_orders; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT pk_orders PRIMARY KEY (id);


--
-- Name: preference_options pk_preference_options; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preference_options
    ADD CONSTRAINT pk_preference_options PRIMARY KEY (id);


--
-- Name: product_categories pk_product_categories; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT pk_product_categories PRIMARY KEY (id);


--
-- Name: product_stock_reservations pk_product_stock_reservations; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_stock_reservations
    ADD CONSTRAINT pk_product_stock_reservations PRIMARY KEY (id);


--
-- Name: product_variant_min_stocks pk_product_variant_min_stocks; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variant_min_stocks
    ADD CONSTRAINT pk_product_variant_min_stocks PRIMARY KEY (variant_id, location_id);


--
-- Name: product_variants pk_product_variants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT pk_product_variants PRIMARY KEY (id);


--
-- Name: products pk_products; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT pk_products PRIMARY KEY (id);


--
-- Name: rental_inventory_movement_items pk_rental_inventory_movement_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_inventory_movement_items
    ADD CONSTRAINT pk_rental_inventory_movement_items PRIMARY KEY (id);


--
-- Name: rental_listings pk_rental_listings; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_listings
    ADD CONSTRAINT pk_rental_listings PRIMARY KEY (id);


--
-- Name: rental_sku_variant_min_stocks pk_rental_sku_variant_min_stocks; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variant_min_stocks
    ADD CONSTRAINT pk_rental_sku_variant_min_stocks PRIMARY KEY (rental_sku_variant_id, location_id);


--
-- Name: rental_sku_variant_stocks pk_rental_sku_variant_stocks; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variant_stocks
    ADD CONSTRAINT pk_rental_sku_variant_stocks PRIMARY KEY (location_id, rental_sku_variant_id);


--
-- Name: rental_sku_variants pk_rental_sku_variants; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variants
    ADD CONSTRAINT pk_rental_sku_variants PRIMARY KEY (id);


--
-- Name: rental_skus pk_rental_skus; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_skus
    ADD CONSTRAINT pk_rental_skus PRIMARY KEY (id);


--
-- Name: rental_stock_reservations pk_rental_stock_reservations; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_stock_reservations
    ADD CONSTRAINT pk_rental_stock_reservations PRIMARY KEY (id);


--
-- Name: review_photos pk_review_photos; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_photos
    ADD CONSTRAINT pk_review_photos PRIMARY KEY (review_id, sort_order);


--
-- Name: reviews pk_reviews; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT pk_reviews PRIMARY KEY (id);


--
-- Name: store_inventory_movement_items pk_store_inventory_movement_items; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_inventory_movement_items
    ADD CONSTRAINT pk_store_inventory_movement_items PRIMARY KEY (id);


--
-- Name: zone_blocks pk_zone_blocks; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone_blocks
    ADD CONSTRAINT pk_zone_blocks PRIMARY KEY (id);


--
-- Name: admin_users uq_admin_users_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT uq_admin_users_email UNIQUE (email);


--
-- Name: article_content_blocks uq_article_content_blocks_article_id_sort_order; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_content_blocks
    ADD CONSTRAINT uq_article_content_blocks_article_id_sort_order UNIQUE (article_id, sort_order);


--
-- Name: article_related_products uq_article_related_products_article_id_sort_order; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_related_products
    ADD CONSTRAINT uq_article_related_products_article_id_sort_order UNIQUE (article_id, sort_order);


--
-- Name: booking_selected_rentals uq_booking_selected_rentals_id_rental_sku_variant_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_rentals
    ADD CONSTRAINT uq_booking_selected_rentals_id_rental_sku_variant_id UNIQUE (id, rental_sku_variant_id);


--
-- Name: branch_features uq_branch_features_branch_id_feature; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_features
    ADD CONSTRAINT uq_branch_features_branch_id_feature UNIQUE (branch_id, feature);


--
-- Name: brands uq_brands_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.brands
    ADD CONSTRAINT uq_brands_name UNIQUE (name);


--
-- Name: campground_closures uq_campground_closures_legacy_closure_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_closures
    ADD CONSTRAINT uq_campground_closures_legacy_closure_id UNIQUE (legacy_closure_id);


--
-- Name: campground_rental_locations uq_campground_rental_locations_location_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_rental_locations
    ADD CONSTRAINT uq_campground_rental_locations_location_id UNIQUE (location_id);


--
-- Name: campground_zones uq_campground_zones_id_campground_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_zones
    ADD CONSTRAINT uq_campground_zones_id_campground_id UNIQUE (id, campground_id);


--
-- Name: coupon_usage_adjustments uq_coupon_usage_adjustments_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_usage_adjustments
    ADD CONSTRAINT uq_coupon_usage_adjustments_idempotency_key UNIQUE (idempotency_key);


--
-- Name: coupons uq_coupons_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT uq_coupons_code UNIQUE (code);


--
-- Name: customer_tags uq_customer_tags_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_tags
    ADD CONSTRAINT uq_customer_tags_name UNIQUE (name);


--
-- Name: customers uq_customers_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT uq_customers_email UNIQUE (email);


--
-- Name: environment_tags uq_environment_tags_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.environment_tags
    ADD CONSTRAINT uq_environment_tags_code UNIQUE (code);


--
-- Name: environment_tags uq_environment_tags_label; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.environment_tags
    ADD CONSTRAINT uq_environment_tags_label UNIQUE (label);


--
-- Name: facility_tags uq_facility_tags_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_tags
    ADD CONSTRAINT uq_facility_tags_code UNIQUE (code);


--
-- Name: facility_tags uq_facility_tags_label; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.facility_tags
    ADD CONSTRAINT uq_facility_tags_label UNIQUE (label);


--
-- Name: inventory_conversions uq_inventory_conversions_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT uq_inventory_conversions_idempotency_key UNIQUE (idempotency_key);


--
-- Name: inventory_conversions uq_inventory_conversions_source_destination; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT uq_inventory_conversions_source_destination UNIQUE (source_movement_id, destination_movement_id);


--
-- Name: inventory_locations uq_inventory_locations_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_locations
    ADD CONSTRAINT uq_inventory_locations_code UNIQUE (code);


--
-- Name: inventory_locations uq_inventory_locations_id_inventory_domain; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_locations
    ADD CONSTRAINT uq_inventory_locations_id_inventory_domain UNIQUE (id, inventory_domain);


--
-- Name: inventory_movements uq_inventory_movements_id_inventory_domain; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_movements
    ADD CONSTRAINT uq_inventory_movements_id_inventory_domain UNIQUE (id, inventory_domain);


--
-- Name: inventory_movements uq_inventory_movements_movement_no; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_movements
    ADD CONSTRAINT uq_inventory_movements_movement_no UNIQUE (movement_no);


--
-- Name: order_coupons uq_order_coupons_order_id_code_snapshot; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_coupons
    ADD CONSTRAINT uq_order_coupons_order_id_code_snapshot UNIQUE (order_id, code_snapshot);


--
-- Name: order_items uq_order_items_id_variant_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT uq_order_items_id_variant_id UNIQUE (id, variant_id);


--
-- Name: preference_options uq_preference_options_type_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preference_options
    ADD CONSTRAINT uq_preference_options_type_code UNIQUE (type, code);


--
-- Name: preference_options uq_preference_options_type_label; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preference_options
    ADD CONSTRAINT uq_preference_options_type_label UNIQUE (type, label);


--
-- Name: product_categories uq_product_categories_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT uq_product_categories_code UNIQUE (code);


--
-- Name: product_categories uq_product_categories_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_categories
    ADD CONSTRAINT uq_product_categories_name UNIQUE (name);


--
-- Name: product_stock_reservations uq_product_stock_reservations_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_stock_reservations
    ADD CONSTRAINT uq_product_stock_reservations_idempotency_key UNIQUE (idempotency_key);


--
-- Name: product_variants uq_product_variants_product_id_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT uq_product_variants_product_id_id UNIQUE (product_id, id);


--
-- Name: product_variants uq_product_variants_sku; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT uq_product_variants_sku UNIQUE (sku);


--
-- Name: products uq_products_item_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT uq_products_item_id UNIQUE (item_id);


--
-- Name: rental_listings uq_rental_listings_campground_id_rental_sku_variant_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_listings
    ADD CONSTRAINT uq_rental_listings_campground_id_rental_sku_variant_id UNIQUE (campground_id, rental_sku_variant_id);


--
-- Name: rental_sku_variants uq_rental_sku_variants_rental_sku_id_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variants
    ADD CONSTRAINT uq_rental_sku_variants_rental_sku_id_id UNIQUE (rental_sku_id, id);


--
-- Name: rental_sku_variants uq_rental_sku_variants_sku; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variants
    ADD CONSTRAINT uq_rental_sku_variants_sku UNIQUE (sku);


--
-- Name: rental_skus uq_rental_skus_item_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_skus
    ADD CONSTRAINT uq_rental_skus_item_id UNIQUE (item_id);


--
-- Name: rental_stock_reservations uq_rental_stock_reservations_idempotency_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_stock_reservations
    ADD CONSTRAINT uq_rental_stock_reservations_idempotency_key UNIQUE (idempotency_key);


--
-- Name: reviews uq_reviews_order_item_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT uq_reviews_order_item_id UNIQUE (order_item_id);


--
-- Name: zone_blocks uq_zone_blocks_legacy_block_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone_blocks
    ADD CONSTRAINT uq_zone_blocks_legacy_block_id UNIQUE (legacy_block_id);


--
-- Name: idx_bookings_camp_dates; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_bookings_camp_dates ON migration.p4_legacy_bookings USING btree (campground_id, check_in, check_out);


--
-- Name: idx_bookings_customer; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_bookings_customer ON migration.p4_legacy_bookings USING btree (customer_id);


--
-- Name: idx_bookings_status; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_bookings_status ON migration.p4_legacy_bookings USING btree (status);


--
-- Name: idx_campground_closures_campground_id; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_campground_closures_campground_id ON migration.p5_legacy_campground_closures USING btree (campground_id);


--
-- Name: idx_campground_closures_created_by; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_campground_closures_created_by ON migration.p5_legacy_campground_closures USING btree (created_by);


--
-- Name: idx_movement_migration_map_conversion; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_movement_migration_map_conversion ON migration.movement_migration_map USING btree (conversion_id);


--
-- Name: idx_movement_migration_map_rental_item; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_movement_migration_map_rental_item ON migration.movement_migration_map USING btree (rental_item_id);


--
-- Name: idx_movement_migration_map_store_item; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_movement_migration_map_store_item ON migration.movement_migration_map USING btree (store_item_id);


--
-- Name: idx_movements_employee_id; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_movements_employee_id ON migration.p5_legacy_movements USING btree (employee_id);


--
-- Name: idx_order_items_order; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_order_items_order ON migration.p4_legacy_order_items USING btree (order_id);


--
-- Name: idx_orders_customer; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_orders_customer ON migration.p4_legacy_orders USING btree (customer_id);


--
-- Name: idx_orders_status; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_orders_status ON migration.p4_legacy_orders USING btree (status);


--
-- Name: idx_p1_location_aliases_location; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_p1_location_aliases_location ON migration.p1_location_aliases USING btree (location_id);


--
-- Name: idx_rental_variant_stock_lookup; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_rental_variant_stock_lookup ON migration.p3_legacy_rental_sku_variant_stocks USING btree (variant_id, campground_id);


--
-- Name: idx_zone_blocks_campground_id; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_zone_blocks_campground_id ON migration.p5_legacy_zone_blocks USING btree (campground_id);


--
-- Name: idx_zone_blocks_created_by; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_zone_blocks_created_by ON migration.p5_legacy_zone_blocks USING btree (created_by);


--
-- Name: idx_zone_blocks_zone_id; Type: INDEX; Schema: migration; Owner: -
--

CREATE INDEX idx_zone_blocks_zone_id ON migration.p5_legacy_zone_blocks USING btree (zone_id);


--
-- Name: idx_admin_users_role_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_role_active ON public.admin_users USING btree (role, active);


--
-- Name: idx_article_content_blocks_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_article_content_blocks_product ON public.article_content_blocks USING btree (product_id);


--
-- Name: idx_article_related_products_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_article_related_products_product ON public.article_related_products USING btree (product_id);


--
-- Name: idx_article_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_article_tags_tag ON public.article_tags USING btree (tag);


--
-- Name: idx_articles_category_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articles_category_published ON public.articles USING btree (category, published_at);


--
-- Name: idx_articles_featured_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_articles_featured_published ON public.articles USING btree (featured, published_at);


--
-- Name: idx_booking_policy_availability_statuses_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_policy_availability_statuses_status ON public.booking_policy_availability_statuses USING btree (status);


--
-- Name: idx_booking_policy_occupying_statuses_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_policy_occupying_statuses_status ON public.booking_policy_occupying_statuses USING btree (status);


--
-- Name: idx_booking_selected_rentals_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_selected_rentals_booking ON public.booking_selected_rentals USING btree (booking_id);


--
-- Name: idx_booking_selected_rentals_listing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_selected_rentals_listing ON public.booking_selected_rentals USING btree (rental_listing_id);


--
-- Name: idx_booking_selected_rentals_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_selected_rentals_variant ON public.booking_selected_rentals USING btree (rental_sku_variant_id);


--
-- Name: idx_booking_selected_zones_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_selected_zones_booking ON public.booking_selected_zones USING btree (booking_id);


--
-- Name: idx_booking_selected_zones_zone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_selected_zones_zone ON public.booking_selected_zones USING btree (zone_id);


--
-- Name: idx_booking_status_history_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_status_history_actor ON public.booking_status_history USING btree (actor_id);


--
-- Name: idx_booking_status_history_booking_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_booking_status_history_booking_time ON public.booking_status_history USING btree (booking_id, occurred_at);


--
-- Name: idx_bookings_campground_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_campground_dates ON public.bookings USING btree (campground_id, check_in, check_out);


--
-- Name: idx_bookings_customer_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_customer_created ON public.bookings USING btree (customer_id, created_at);


--
-- Name: idx_branch_features_feature; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_features_feature ON public.branch_features USING btree (feature);


--
-- Name: idx_brands_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_brands_active_sort ON public.brands USING btree (active, sort_order);


--
-- Name: idx_calendar_dates_holiday_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_dates_holiday_date ON public.calendar_dates USING btree (is_holiday, calendar_date);


--
-- Name: idx_campground_closures_campground_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campground_closures_campground_dates ON public.campground_closures USING btree (campground_id, start_date, end_date);


--
-- Name: idx_campground_closures_campground_weekday; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campground_closures_campground_weekday ON public.campground_closures USING btree (campground_id, weekday);


--
-- Name: idx_campground_closures_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campground_closures_created_by ON public.campground_closures USING btree (created_by);


--
-- Name: idx_campground_environment_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campground_environment_tags_tag ON public.campground_environment_tags USING btree (tag_id);


--
-- Name: idx_campground_facility_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campground_facility_tags_tag ON public.campground_facility_tags USING btree (tag_id);


--
-- Name: idx_campground_zones_campground_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campground_zones_campground_active ON public.campground_zones USING btree (campground_id, active);


--
-- Name: idx_campgrounds_region_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_campgrounds_region_active ON public.campgrounds USING btree (region, active);


--
-- Name: idx_coupon_usage_adjustments_order_coupon_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupon_usage_adjustments_order_coupon_time ON public.coupon_usage_adjustments USING btree (order_coupon_id, created_at);


--
-- Name: idx_coupons_status_validity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_coupons_status_validity ON public.coupons USING btree (status, valid_from, valid_until);


--
-- Name: idx_customer_preferences_preference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_preferences_preference ON public.customer_preferences USING btree (preference_id);


--
-- Name: idx_customer_shipping_addresses_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_shipping_addresses_customer ON public.customer_shipping_addresses USING btree (customer_id);


--
-- Name: idx_customer_shipping_addresses_one_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_customer_shipping_addresses_one_default ON public.customer_shipping_addresses USING btree (customer_id) WHERE is_default;


--
-- Name: idx_customer_tag_assignments_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_tag_assignments_tag ON public.customer_tag_assignments USING btree (tag_id);


--
-- Name: idx_customer_tags_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customer_tags_active_sort ON public.customer_tags USING btree (active, sort_order);


--
-- Name: idx_customers_auth_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_customers_auth_provider ON public.customers USING btree (auth_provider);


CREATE INDEX idx_customers_active_email ON public.customers USING btree (email) WHERE ((active = true) AND (deleted_at IS NULL));


--
-- Name: idx_environment_tags_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_environment_tags_active_sort ON public.environment_tags USING btree (active, sort_order);


--
-- Name: idx_equipment_images_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_equipment_images_sort_order ON public.equipment_images USING btree (sort_order);


--
-- Name: idx_equipment_interest_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_equipment_interest_tags_tag ON public.equipment_interest_tags USING btree (tag);


--
-- Name: idx_equipment_items_brand; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_equipment_items_brand ON public.equipment_items USING btree (brand_id);


--
-- Name: idx_equipment_items_category_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_equipment_items_category_active ON public.equipment_items USING btree (category_id, active);


--
-- Name: idx_equipment_specifications_spec_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_equipment_specifications_spec_key ON public.equipment_specifications USING btree (spec_key);


--
-- Name: idx_equipment_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_equipment_tags_tag ON public.equipment_tags USING btree (tag);


--
-- Name: idx_facility_tags_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_facility_tags_active_sort ON public.facility_tags USING btree (active, sort_order);


--
-- Name: idx_inventory_conversions_destination_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_conversions_destination_location ON public.inventory_conversions USING btree (destination_location_id);


--
-- Name: idx_inventory_conversions_destination_movement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_conversions_destination_movement ON public.inventory_conversions USING btree (destination_movement_id);


--
-- Name: idx_inventory_conversions_destination_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_conversions_destination_variant ON public.inventory_conversions USING btree (destination_rental_variant_id);


--
-- Name: idx_inventory_conversions_source_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_conversions_source_location ON public.inventory_conversions USING btree (source_location_id);


--
-- Name: idx_inventory_conversions_source_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_conversions_source_variant ON public.inventory_conversions USING btree (source_variant_id);


--
-- Name: idx_inventory_locations_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_locations_branch ON public.inventory_locations USING btree (branch_id);


--
-- Name: idx_inventory_locations_domain_type_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_locations_domain_type_active ON public.inventory_locations USING btree (inventory_domain, type, active);


--
-- Name: idx_inventory_movements_destination_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_movements_destination_domain ON public.inventory_movements USING btree (destination_location_id, inventory_domain);


--
-- Name: idx_inventory_movements_domain_status_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_movements_domain_status_time ON public.inventory_movements USING btree (inventory_domain, status, occurred_at);


--
-- Name: idx_inventory_movements_employee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_movements_employee ON public.inventory_movements USING btree (employee_id);


--
-- Name: idx_inventory_movements_legacy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_movements_legacy ON public.inventory_movements USING btree (legacy_movement_id);


--
-- Name: idx_inventory_movements_source_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_movements_source_domain ON public.inventory_movements USING btree (source_location_id, inventory_domain);


--
-- Name: idx_inventory_stocks_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_stocks_variant ON public.inventory_stocks USING btree (variant_id);


--
-- Name: idx_legacy_reviews_customer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_reviews_customer ON public.legacy_reviews USING btree (customer_id);


--
-- Name: idx_legacy_reviews_product_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_legacy_reviews_product_variant ON public.legacy_reviews USING btree (product_id, variant_id);


--
-- Name: idx_order_coupons_coupon; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_coupons_coupon ON public.order_coupons USING btree (coupon_id);


--
-- Name: idx_order_items_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_order ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_product ON public.order_items USING btree (product_id);


--
-- Name: idx_order_items_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_items_variant ON public.order_items USING btree (variant_id);


--
-- Name: idx_order_status_history_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_status_history_actor ON public.order_status_history USING btree (actor_id);


--
-- Name: idx_order_status_history_order_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_order_status_history_order_time ON public.order_status_history USING btree (order_id, occurred_at);


--
-- Name: idx_orders_customer_placed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_customer_placed ON public.orders USING btree (customer_id, placed_at);


--
-- Name: idx_orders_status_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_status_payment ON public.orders USING btree (status, payment_status);


--
-- Name: idx_preference_options_type_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_preference_options_type_active_sort ON public.preference_options USING btree (type, active, sort_order);


--
-- Name: idx_product_categories_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_categories_active_sort ON public.product_categories USING btree (active, sort_order);


--
-- Name: idx_product_stock_reservations_active_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_stock_reservations_active_lookup ON public.product_stock_reservations USING btree (variant_id, location_id) WHERE ((status)::text = 'active'::text);


--
-- Name: idx_product_stock_reservations_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_stock_reservations_expiry ON public.product_stock_reservations USING btree (expires_at) WHERE (((status)::text = 'active'::text) AND (expires_at IS NOT NULL));


--
-- Name: idx_product_stock_reservations_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_stock_reservations_location ON public.product_stock_reservations USING btree (location_id);


--
-- Name: idx_product_stock_reservations_location_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_stock_reservations_location_domain ON public.product_stock_reservations USING btree (location_id, inventory_domain);


--
-- Name: idx_product_stock_reservations_order_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_stock_reservations_order_item ON public.product_stock_reservations USING btree (order_item_id);


--
-- Name: idx_product_stock_reservations_order_item_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_stock_reservations_order_item_variant ON public.product_stock_reservations USING btree (order_item_id, variant_id);


--
-- Name: idx_product_variant_min_stocks_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_variant_min_stocks_location ON public.product_variant_min_stocks USING btree (location_id);


--
-- Name: idx_product_variants_product_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_variants_product_status ON public.product_variants USING btree (product_id, status);


--
-- Name: idx_products_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_status ON public.products USING btree (status);


--
-- Name: idx_rental_inventory_movement_items_movement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_inventory_movement_items_movement ON public.rental_inventory_movement_items USING btree (movement_id, inventory_domain);


--
-- Name: idx_rental_inventory_movement_items_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_inventory_movement_items_variant ON public.rental_inventory_movement_items USING btree (rental_sku_variant_id);


--
-- Name: idx_rental_listings_variant_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_listings_variant_active ON public.rental_listings USING btree (rental_sku_variant_id, active);


--
-- Name: idx_rental_sku_variant_min_stocks_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_sku_variant_min_stocks_location ON public.rental_sku_variant_min_stocks USING btree (location_id);


--
-- Name: idx_rental_sku_variant_stocks_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_sku_variant_stocks_variant ON public.rental_sku_variant_stocks USING btree (rental_sku_variant_id);


--
-- Name: idx_rental_sku_variants_sku_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_sku_variants_sku_status ON public.rental_sku_variants USING btree (rental_sku_id, status);


--
-- Name: idx_rental_skus_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_skus_status ON public.rental_skus USING btree (status);


--
-- Name: idx_rental_stock_reservations_active_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_stock_reservations_active_range ON public.rental_stock_reservations USING btree (rental_sku_variant_id, location_id, check_in, check_out) WHERE ((status)::text = 'active'::text);


--
-- Name: idx_rental_stock_reservations_booking_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_stock_reservations_booking_item ON public.rental_stock_reservations USING btree (booking_selected_rental_id);


--
-- Name: idx_rental_stock_reservations_booking_item_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_stock_reservations_booking_item_variant ON public.rental_stock_reservations USING btree (booking_selected_rental_id, rental_sku_variant_id);


--
-- Name: idx_rental_stock_reservations_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_stock_reservations_location ON public.rental_stock_reservations USING btree (location_id);


--
-- Name: idx_rental_stock_reservations_location_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rental_stock_reservations_location_domain ON public.rental_stock_reservations USING btree (location_id, inventory_domain);


--
-- Name: idx_reviews_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_created_at ON public.reviews USING btree (created_at);


--
-- Name: idx_store_inventory_movement_items_movement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_inventory_movement_items_movement ON public.store_inventory_movement_items USING btree (movement_id, inventory_domain);


--
-- Name: idx_store_inventory_movement_items_variant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_inventory_movement_items_variant ON public.store_inventory_movement_items USING btree (variant_id);


--
-- Name: idx_zone_blocks_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_zone_blocks_created_by ON public.zone_blocks USING btree (created_by);


--
-- Name: idx_zone_blocks_zone_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_zone_blocks_zone_dates ON public.zone_blocks USING btree (campground_id, zone_id, start_date, end_date);


--
-- Name: movement_migration_map trg_movement_migration_map_read_only; Type: TRIGGER; Schema: migration; Owner: -
--

CREATE TRIGGER trg_movement_migration_map_read_only BEFORE INSERT OR DELETE OR UPDATE OR TRUNCATE ON migration.movement_migration_map FOR EACH STATEMENT EXECUTE FUNCTION migration.reject_p7_archive_write();


--
-- Name: p7_contract_evidence trg_p7_contract_evidence_read_only; Type: TRIGGER; Schema: migration; Owner: -
--

CREATE TRIGGER trg_p7_contract_evidence_read_only BEFORE INSERT OR DELETE OR UPDATE OR TRUNCATE ON migration.p7_contract_evidence FOR EACH STATEMENT EXECUTE FUNCTION migration.reject_p7_archive_write();


--
-- Name: campground_rental_locations trg_campground_rental_locations_type; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_campground_rental_locations_type AFTER INSERT OR UPDATE OF location_id ON public.campground_rental_locations DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.enforce_campground_rental_location_type();


CREATE TRIGGER trg_customers_prevent_hard_delete BEFORE DELETE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.reject_customer_hard_delete();


--
-- Name: inventory_conversions trg_inventory_conversions_domains; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_inventory_conversions_domains AFTER INSERT OR UPDATE ON public.inventory_conversions DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.enforce_inventory_conversion_domains();


--
-- Name: inventory_conversions trg_inventory_conversions_draft_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inventory_conversions_draft_only BEFORE INSERT OR DELETE OR UPDATE ON public.inventory_conversions FOR EACH ROW EXECUTE FUNCTION public.protect_inventory_conversion_draft();


--
-- Name: inventory_locations trg_inventory_locations_protect_minimum_stock_domain; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inventory_locations_protect_minimum_stock_domain BEFORE UPDATE OF inventory_domain ON public.inventory_locations FOR EACH ROW EXECUTE FUNCTION public.protect_minimum_stock_location_domain();


--
-- Name: inventory_locations trg_inventory_locations_protect_rental_mapping; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inventory_locations_protect_rental_mapping BEFORE UPDATE OF inventory_domain, type ON public.inventory_locations FOR EACH ROW EXECUTE FUNCTION public.protect_mapped_rental_location_type();


--
-- Name: inventory_movements trg_inventory_movements_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inventory_movements_immutable BEFORE DELETE OR UPDATE ON public.inventory_movements FOR EACH ROW EXECUTE FUNCTION public.protect_inventory_movement_header();


--
-- Name: legacy_review_photos trg_legacy_review_photos_read_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_legacy_review_photos_read_only BEFORE INSERT OR DELETE OR UPDATE ON public.legacy_review_photos FOR EACH STATEMENT EXECUTE FUNCTION public.reject_legacy_review_write();


--
-- Name: legacy_reviews trg_legacy_reviews_read_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_legacy_reviews_read_only BEFORE INSERT OR DELETE OR UPDATE ON public.legacy_reviews FOR EACH STATEMENT EXECUTE FUNCTION public.reject_legacy_review_write();


--
-- Name: product_stock_reservations trg_product_stock_reservations_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_product_stock_reservations_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.product_stock_reservations FOR EACH ROW EXECUTE FUNCTION public.protect_stock_reservation_lifecycle();


--
-- Name: product_variant_min_stocks trg_product_variant_min_stocks_domain; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_product_variant_min_stocks_domain AFTER INSERT OR UPDATE ON public.product_variant_min_stocks DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.enforce_minimum_stock_location_domain();


--
-- Name: rental_inventory_movement_items trg_rental_inventory_movement_items_draft_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rental_inventory_movement_items_draft_only BEFORE INSERT OR DELETE OR UPDATE ON public.rental_inventory_movement_items FOR EACH ROW EXECUTE FUNCTION public.protect_inventory_movement_detail();


--
-- Name: rental_sku_variant_min_stocks trg_rental_sku_variant_min_stocks_domain; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_rental_sku_variant_min_stocks_domain AFTER INSERT OR UPDATE ON public.rental_sku_variant_min_stocks DEFERRABLE INITIALLY IMMEDIATE FOR EACH ROW EXECUTE FUNCTION public.enforce_minimum_stock_location_domain();


--
-- Name: rental_stock_reservations trg_rental_stock_reservations_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rental_stock_reservations_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.rental_stock_reservations FOR EACH ROW EXECUTE FUNCTION public.protect_stock_reservation_lifecycle();


--
-- Name: store_inventory_movement_items trg_store_inventory_movement_items_draft_only; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_store_inventory_movement_items_draft_only BEFORE INSERT OR DELETE OR UPDATE ON public.store_inventory_movement_items FOR EACH ROW EXECUTE FUNCTION public.protect_inventory_movement_detail();


--
-- Name: p6_legacy_article_content_blocks article_content_blocks_article_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_content_blocks
    ADD CONSTRAINT article_content_blocks_article_id_fkey FOREIGN KEY (article_id) REFERENCES migration.p6_legacy_articles(id) ON DELETE CASCADE;


--
-- Name: p6_legacy_article_content_blocks article_content_blocks_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_content_blocks
    ADD CONSTRAINT article_content_blocks_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p6_legacy_article_related_products article_related_products_article_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_related_products
    ADD CONSTRAINT article_related_products_article_id_fkey FOREIGN KEY (article_id) REFERENCES migration.p6_legacy_articles(id) ON DELETE CASCADE;


--
-- Name: p6_legacy_article_related_products article_related_products_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_article_related_products
    ADD CONSTRAINT article_related_products_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p4_legacy_booking_history booking_history_booking_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_history
    ADD CONSTRAINT booking_history_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES migration.p4_legacy_bookings(id) ON DELETE CASCADE;


--
-- Name: p4_legacy_booking_selected_rentals booking_selected_rentals_booking_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals
    ADD CONSTRAINT booking_selected_rentals_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES migration.p4_legacy_bookings(id) ON DELETE CASCADE;


--
-- Name: p4_legacy_booking_selected_rentals booking_selected_rentals_equipment_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals
    ADD CONSTRAINT booking_selected_rentals_equipment_id_fkey FOREIGN KEY (equipment_id) REFERENCES migration.p3_legacy_rental_listings(id);


--
-- Name: p4_legacy_booking_selected_rentals booking_selected_rentals_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals
    ADD CONSTRAINT booking_selected_rentals_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p4_legacy_booking_selected_rentals booking_selected_rentals_rental_sku_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals
    ADD CONSTRAINT booking_selected_rentals_rental_sku_id_fkey FOREIGN KEY (rental_sku_id) REFERENCES public.rental_skus(id);


--
-- Name: p4_legacy_booking_selected_rentals booking_selected_rentals_variant_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_rentals
    ADD CONSTRAINT booking_selected_rentals_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: p4_legacy_booking_selected_zones booking_selected_zones_booking_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_zones
    ADD CONSTRAINT booking_selected_zones_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES migration.p4_legacy_bookings(id) ON DELETE CASCADE;


--
-- Name: p4_legacy_booking_selected_zones booking_selected_zones_zone_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_booking_selected_zones
    ADD CONSTRAINT booking_selected_zones_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES public.campground_zones(id);


--
-- Name: p4_legacy_bookings bookings_campground_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_bookings
    ADD CONSTRAINT bookings_campground_id_fkey FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id);


--
-- Name: p4_legacy_bookings bookings_customer_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_bookings
    ADD CONSTRAINT bookings_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: p5_legacy_campground_closures campground_closures_campground_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_campground_closures
    ADD CONSTRAINT campground_closures_campground_id_fkey FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id);


--
-- Name: p5_legacy_campground_closures fk_campground_closures_created_by; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_campground_closures
    ADD CONSTRAINT fk_campground_closures_created_by FOREIGN KEY (created_by) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: movement_migration_map fk_movement_migration_map_conversion_id; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.movement_migration_map
    ADD CONSTRAINT fk_movement_migration_map_conversion_id FOREIGN KEY (conversion_id) REFERENCES public.inventory_conversions(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: movement_migration_map fk_movement_migration_map_rental_item_id; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.movement_migration_map
    ADD CONSTRAINT fk_movement_migration_map_rental_item_id FOREIGN KEY (rental_item_id) REFERENCES public.rental_inventory_movement_items(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: movement_migration_map fk_movement_migration_map_store_item_id; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.movement_migration_map
    ADD CONSTRAINT fk_movement_migration_map_store_item_id FOREIGN KEY (store_item_id) REFERENCES public.store_inventory_movement_items(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: p5_legacy_movements fk_movements_employee_id; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movements
    ADD CONSTRAINT fk_movements_employee_id FOREIGN KEY (employee_id) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: p1_location_aliases fk_p1_location_aliases_location; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p1_location_aliases
    ADD CONSTRAINT fk_p1_location_aliases_location FOREIGN KEY (location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: p6_review_resolution fk_p6_review_resolution_order_item; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_review_resolution
    ADD CONSTRAINT fk_p6_review_resolution_order_item FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: p6_review_resolution fk_p6_review_resolution_source; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_review_resolution
    ADD CONSTRAINT fk_p6_review_resolution_source FOREIGN KEY (review_id) REFERENCES migration.p6_review_source(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: p5_legacy_zone_blocks fk_zone_blocks_created_by; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_zone_blocks
    ADD CONSTRAINT fk_zone_blocks_created_by FOREIGN KEY (created_by) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: p5_legacy_movement_items movement_items_movement_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movement_items
    ADD CONSTRAINT movement_items_movement_id_fkey FOREIGN KEY (movement_id) REFERENCES migration.p5_legacy_movements(id) ON DELETE CASCADE;


--
-- Name: p5_legacy_movement_items movement_items_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_movement_items
    ADD CONSTRAINT movement_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p4_legacy_order_coupons order_coupons_coupon_code_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_coupons
    ADD CONSTRAINT order_coupons_coupon_code_fkey FOREIGN KEY (coupon_code) REFERENCES migration.p4_legacy_coupons(code);


--
-- Name: p4_legacy_order_coupons order_coupons_order_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_coupons
    ADD CONSTRAINT order_coupons_order_id_fkey FOREIGN KEY (order_id) REFERENCES migration.p4_legacy_orders(id) ON DELETE CASCADE;


--
-- Name: p4_legacy_order_history order_history_order_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_history
    ADD CONSTRAINT order_history_order_id_fkey FOREIGN KEY (order_id) REFERENCES migration.p4_legacy_orders(id) ON DELETE CASCADE;


--
-- Name: p4_legacy_order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES migration.p4_legacy_orders(id) ON DELETE CASCADE;


--
-- Name: p4_legacy_order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p4_legacy_order_items order_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_order_items
    ADD CONSTRAINT order_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: p4_legacy_orders orders_customer_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p4_legacy_orders
    ADD CONSTRAINT orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: p3_legacy_rental_listings rental_listings_campground_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_listings
    ADD CONSTRAINT rental_listings_campground_id_fkey FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id);


--
-- Name: p3_legacy_rental_listings rental_listings_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_listings
    ADD CONSTRAINT rental_listings_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p3_legacy_rental_listings rental_listings_rental_sku_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_listings
    ADD CONSTRAINT rental_listings_rental_sku_id_fkey FOREIGN KEY (rental_sku_id) REFERENCES public.rental_skus(id);


--
-- Name: p3_legacy_rental_listings rental_listings_variant_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_listings
    ADD CONSTRAINT rental_listings_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: p3_legacy_rental_sku_variant_stocks rental_sku_variant_stocks_rental_sku_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_sku_variant_stocks
    ADD CONSTRAINT rental_sku_variant_stocks_rental_sku_id_fkey FOREIGN KEY (rental_sku_id) REFERENCES public.rental_skus(id);


--
-- Name: p3_legacy_rental_sku_variant_stocks rental_sku_variant_stocks_variant_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p3_legacy_rental_sku_variant_stocks
    ADD CONSTRAINT rental_sku_variant_stocks_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: p6_legacy_reviews reviews_customer_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_reviews
    ADD CONSTRAINT reviews_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: p6_legacy_reviews reviews_order_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_reviews
    ADD CONSTRAINT reviews_order_id_fkey FOREIGN KEY (order_id) REFERENCES migration.p4_legacy_orders(id);


--
-- Name: p6_legacy_reviews reviews_product_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_reviews
    ADD CONSTRAINT reviews_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: p6_legacy_reviews reviews_variant_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p6_legacy_reviews
    ADD CONSTRAINT reviews_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.product_variants(id);


--
-- Name: p5_legacy_zone_blocks zone_blocks_campground_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_zone_blocks
    ADD CONSTRAINT zone_blocks_campground_id_fkey FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id);


--
-- Name: p5_legacy_zone_blocks zone_blocks_zone_id_fkey; Type: FK CONSTRAINT; Schema: migration; Owner: -
--

ALTER TABLE ONLY migration.p5_legacy_zone_blocks
    ADD CONSTRAINT zone_blocks_zone_id_fkey FOREIGN KEY (zone_id) REFERENCES public.campground_zones(id);


--
-- Name: article_content_blocks fk_article_content_blocks_article_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_content_blocks
    ADD CONSTRAINT fk_article_content_blocks_article_id FOREIGN KEY (article_id) REFERENCES public.articles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: article_content_blocks fk_article_content_blocks_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_content_blocks
    ADD CONSTRAINT fk_article_content_blocks_product_id FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: article_related_products fk_article_related_products_article_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_related_products
    ADD CONSTRAINT fk_article_related_products_article_id FOREIGN KEY (article_id) REFERENCES public.articles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: article_related_products fk_article_related_products_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_related_products
    ADD CONSTRAINT fk_article_related_products_product_id FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: article_tags fk_article_tags_article_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_tags
    ADD CONSTRAINT fk_article_tags_article_id FOREIGN KEY (article_id) REFERENCES public.articles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: booking_policy_availability_statuses fk_booking_policy_availability_statuses_policy_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_policy_availability_statuses
    ADD CONSTRAINT fk_booking_policy_availability_statuses_policy_id FOREIGN KEY (policy_id) REFERENCES public.booking_policies(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: booking_policy_occupying_statuses fk_booking_policy_occupying_statuses_policy_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_policy_occupying_statuses
    ADD CONSTRAINT fk_booking_policy_occupying_statuses_policy_id FOREIGN KEY (policy_id) REFERENCES public.booking_policies(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: booking_selected_rentals fk_booking_selected_rentals_booking_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_rentals
    ADD CONSTRAINT fk_booking_selected_rentals_booking_id FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: booking_selected_rentals fk_booking_selected_rentals_rental_listing_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_rentals
    ADD CONSTRAINT fk_booking_selected_rentals_rental_listing_id FOREIGN KEY (rental_listing_id) REFERENCES public.rental_listings(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: booking_selected_rentals fk_booking_selected_rentals_rental_sku_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_rentals
    ADD CONSTRAINT fk_booking_selected_rentals_rental_sku_variant_id FOREIGN KEY (rental_sku_variant_id) REFERENCES public.rental_sku_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: booking_selected_zones fk_booking_selected_zones_booking_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_zones
    ADD CONSTRAINT fk_booking_selected_zones_booking_id FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: booking_selected_zones fk_booking_selected_zones_zone_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_selected_zones
    ADD CONSTRAINT fk_booking_selected_zones_zone_id FOREIGN KEY (zone_id) REFERENCES public.campground_zones(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: booking_status_history fk_booking_status_history_actor_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_status_history
    ADD CONSTRAINT fk_booking_status_history_actor_id FOREIGN KEY (actor_id) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: booking_status_history fk_booking_status_history_booking_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.booking_status_history
    ADD CONSTRAINT fk_booking_status_history_booking_id FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: bookings fk_bookings_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_bookings_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: bookings fk_bookings_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT fk_bookings_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: branch_features fk_branch_features_branch_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_features
    ADD CONSTRAINT fk_branch_features_branch_id FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: campground_closures fk_campground_closures_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_closures
    ADD CONSTRAINT fk_campground_closures_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: campground_closures fk_campground_closures_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_closures
    ADD CONSTRAINT fk_campground_closures_created_by FOREIGN KEY (created_by) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: campground_environment_tags fk_campground_environment_tags_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_environment_tags
    ADD CONSTRAINT fk_campground_environment_tags_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: campground_environment_tags fk_campground_environment_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_environment_tags
    ADD CONSTRAINT fk_campground_environment_tags_tag_id FOREIGN KEY (tag_id) REFERENCES public.environment_tags(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: campground_facility_tags fk_campground_facility_tags_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_facility_tags
    ADD CONSTRAINT fk_campground_facility_tags_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: campground_facility_tags fk_campground_facility_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_facility_tags
    ADD CONSTRAINT fk_campground_facility_tags_tag_id FOREIGN KEY (tag_id) REFERENCES public.facility_tags(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: campground_rental_locations fk_campground_rental_locations_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_rental_locations
    ADD CONSTRAINT fk_campground_rental_locations_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: campground_rental_locations fk_campground_rental_locations_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_rental_locations
    ADD CONSTRAINT fk_campground_rental_locations_location_id FOREIGN KEY (location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: campground_zones fk_campground_zones_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campground_zones
    ADD CONSTRAINT fk_campground_zones_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: coupon_usage_adjustments fk_coupon_usage_adjustments_order_coupon_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupon_usage_adjustments
    ADD CONSTRAINT fk_coupon_usage_adjustments_order_coupon_id FOREIGN KEY (order_coupon_id) REFERENCES public.order_coupons(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: customer_preferences fk_customer_preferences_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_preferences
    ADD CONSTRAINT fk_customer_preferences_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: customer_preferences fk_customer_preferences_preference_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_preferences
    ADD CONSTRAINT fk_customer_preferences_preference_id FOREIGN KEY (preference_id) REFERENCES public.preference_options(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: customer_shipping_addresses fk_customer_shipping_addresses_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_shipping_addresses
    ADD CONSTRAINT fk_customer_shipping_addresses_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: customer_tag_assignments fk_customer_tag_assignments_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_tag_assignments
    ADD CONSTRAINT fk_customer_tag_assignments_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: customer_tag_assignments fk_customer_tag_assignments_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_tag_assignments
    ADD CONSTRAINT fk_customer_tag_assignments_tag_id FOREIGN KEY (tag_id) REFERENCES public.customer_tags(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: equipment_images fk_equipment_images_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_images
    ADD CONSTRAINT fk_equipment_images_item_id FOREIGN KEY (item_id) REFERENCES public.equipment_items(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: equipment_interest_tags fk_equipment_interest_tags_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_interest_tags
    ADD CONSTRAINT fk_equipment_interest_tags_item_id FOREIGN KEY (item_id) REFERENCES public.equipment_items(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: equipment_items fk_equipment_items_brand_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_items
    ADD CONSTRAINT fk_equipment_items_brand_id FOREIGN KEY (brand_id) REFERENCES public.brands(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: equipment_items fk_equipment_items_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_items
    ADD CONSTRAINT fk_equipment_items_category_id FOREIGN KEY (category_id) REFERENCES public.product_categories(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: equipment_specifications fk_equipment_specifications_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_specifications
    ADD CONSTRAINT fk_equipment_specifications_item_id FOREIGN KEY (item_id) REFERENCES public.equipment_items(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: equipment_tags fk_equipment_tags_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipment_tags
    ADD CONSTRAINT fk_equipment_tags_item_id FOREIGN KEY (item_id) REFERENCES public.equipment_items(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: inventory_conversions fk_inventory_conversions_destination_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT fk_inventory_conversions_destination_location_id FOREIGN KEY (destination_location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_conversions fk_inventory_conversions_destination_movement_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT fk_inventory_conversions_destination_movement_id FOREIGN KEY (destination_movement_id) REFERENCES public.inventory_movements(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_conversions fk_inventory_conversions_destination_rental_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT fk_inventory_conversions_destination_rental_variant_id FOREIGN KEY (destination_rental_variant_id) REFERENCES public.rental_sku_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_conversions fk_inventory_conversions_source_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT fk_inventory_conversions_source_location_id FOREIGN KEY (source_location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_conversions fk_inventory_conversions_source_movement_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT fk_inventory_conversions_source_movement_id FOREIGN KEY (source_movement_id) REFERENCES public.inventory_movements(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_conversions fk_inventory_conversions_source_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_conversions
    ADD CONSTRAINT fk_inventory_conversions_source_variant_id FOREIGN KEY (source_variant_id) REFERENCES public.product_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_locations fk_inventory_locations_branch_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_locations
    ADD CONSTRAINT fk_inventory_locations_branch_id FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_movements fk_inventory_movements_destination_location_domain; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_movements
    ADD CONSTRAINT fk_inventory_movements_destination_location_domain FOREIGN KEY (destination_location_id, inventory_domain) REFERENCES public.inventory_locations(id, inventory_domain) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_movements fk_inventory_movements_employee_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_movements
    ADD CONSTRAINT fk_inventory_movements_employee_id FOREIGN KEY (employee_id) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_movements fk_inventory_movements_source_location_domain; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_movements
    ADD CONSTRAINT fk_inventory_movements_source_location_domain FOREIGN KEY (source_location_id, inventory_domain) REFERENCES public.inventory_locations(id, inventory_domain) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_stocks fk_inventory_stocks_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_stocks
    ADD CONSTRAINT fk_inventory_stocks_location_id FOREIGN KEY (location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inventory_stocks fk_inventory_stocks_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_stocks
    ADD CONSTRAINT fk_inventory_stocks_variant_id FOREIGN KEY (variant_id) REFERENCES public.product_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: legacy_review_photos fk_legacy_review_photos_legacy_review_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_review_photos
    ADD CONSTRAINT fk_legacy_review_photos_legacy_review_id FOREIGN KEY (legacy_review_id) REFERENCES public.legacy_reviews(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: legacy_reviews fk_legacy_reviews_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_reviews
    ADD CONSTRAINT fk_legacy_reviews_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: legacy_reviews fk_legacy_reviews_product_id_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.legacy_reviews
    ADD CONSTRAINT fk_legacy_reviews_product_id_variant_id FOREIGN KEY (product_id, variant_id) REFERENCES public.product_variants(product_id, id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: order_coupons fk_order_coupons_coupon_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_coupons
    ADD CONSTRAINT fk_order_coupons_coupon_id FOREIGN KEY (coupon_id) REFERENCES public.coupons(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: order_coupons fk_order_coupons_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_coupons
    ADD CONSTRAINT fk_order_coupons_order_id FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: order_items fk_order_items_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_order_items_order_id FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: order_items fk_order_items_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_order_items_product_id FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: order_items fk_order_items_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_order_items_variant_id FOREIGN KEY (variant_id) REFERENCES public.product_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: order_status_history fk_order_status_history_actor_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT fk_order_status_history_actor_id FOREIGN KEY (actor_id) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: order_status_history fk_order_status_history_order_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_history
    ADD CONSTRAINT fk_order_status_history_order_id FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: orders fk_orders_customer_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_orders_customer_id FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: product_stock_reservations fk_product_stock_reservations_location_domain; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_stock_reservations
    ADD CONSTRAINT fk_product_stock_reservations_location_domain FOREIGN KEY (location_id, inventory_domain) REFERENCES public.inventory_locations(id, inventory_domain) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: product_stock_reservations fk_product_stock_reservations_order_item_id_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_stock_reservations
    ADD CONSTRAINT fk_product_stock_reservations_order_item_id_variant_id FOREIGN KEY (order_item_id, variant_id) REFERENCES public.order_items(id, variant_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: product_variant_min_stocks fk_product_variant_min_stocks_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variant_min_stocks
    ADD CONSTRAINT fk_product_variant_min_stocks_location_id FOREIGN KEY (location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: product_variant_min_stocks fk_product_variant_min_stocks_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variant_min_stocks
    ADD CONSTRAINT fk_product_variant_min_stocks_variant_id FOREIGN KEY (variant_id) REFERENCES public.product_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: product_variants fk_product_variants_product_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_product_variants_product_id FOREIGN KEY (product_id) REFERENCES public.products(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: products fk_products_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_products_item_id FOREIGN KEY (item_id) REFERENCES public.equipment_items(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_inventory_movement_items fk_rental_inventory_movement_items_movement_id_inventory_domain; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_inventory_movement_items
    ADD CONSTRAINT fk_rental_inventory_movement_items_movement_id_inventory_domain FOREIGN KEY (movement_id, inventory_domain) REFERENCES public.inventory_movements(id, inventory_domain) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_inventory_movement_items fk_rental_inventory_movement_items_rental_sku_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_inventory_movement_items
    ADD CONSTRAINT fk_rental_inventory_movement_items_rental_sku_variant_id FOREIGN KEY (rental_sku_variant_id) REFERENCES public.rental_sku_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_listings fk_rental_listings_campground_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_listings
    ADD CONSTRAINT fk_rental_listings_campground_id FOREIGN KEY (campground_id) REFERENCES public.campgrounds(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_listings fk_rental_listings_campground_location; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_listings
    ADD CONSTRAINT fk_rental_listings_campground_location FOREIGN KEY (campground_id) REFERENCES public.campground_rental_locations(campground_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_listings fk_rental_listings_rental_sku_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_listings
    ADD CONSTRAINT fk_rental_listings_rental_sku_variant_id FOREIGN KEY (rental_sku_variant_id) REFERENCES public.rental_sku_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_sku_variant_min_stocks fk_rental_sku_variant_min_stocks_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variant_min_stocks
    ADD CONSTRAINT fk_rental_sku_variant_min_stocks_location_id FOREIGN KEY (location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_sku_variant_min_stocks fk_rental_sku_variant_min_stocks_rental_sku_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variant_min_stocks
    ADD CONSTRAINT fk_rental_sku_variant_min_stocks_rental_sku_variant_id FOREIGN KEY (rental_sku_variant_id) REFERENCES public.rental_sku_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_sku_variant_stocks fk_rental_sku_variant_stocks_location_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variant_stocks
    ADD CONSTRAINT fk_rental_sku_variant_stocks_location_id FOREIGN KEY (location_id) REFERENCES public.inventory_locations(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_sku_variant_stocks fk_rental_sku_variant_stocks_rental_sku_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variant_stocks
    ADD CONSTRAINT fk_rental_sku_variant_stocks_rental_sku_variant_id FOREIGN KEY (rental_sku_variant_id) REFERENCES public.rental_sku_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_sku_variants fk_rental_sku_variants_rental_sku_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_sku_variants
    ADD CONSTRAINT fk_rental_sku_variants_rental_sku_id FOREIGN KEY (rental_sku_id) REFERENCES public.rental_skus(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_skus fk_rental_skus_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_skus
    ADD CONSTRAINT fk_rental_skus_item_id FOREIGN KEY (item_id) REFERENCES public.equipment_items(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_stock_reservations fk_rental_stock_reservations_booking_selected_rental_id_rental_; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_stock_reservations
    ADD CONSTRAINT fk_rental_stock_reservations_booking_selected_rental_id_rental_ FOREIGN KEY (booking_selected_rental_id, rental_sku_variant_id) REFERENCES public.booking_selected_rentals(id, rental_sku_variant_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: rental_stock_reservations fk_rental_stock_reservations_location_domain; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_stock_reservations
    ADD CONSTRAINT fk_rental_stock_reservations_location_domain FOREIGN KEY (location_id, inventory_domain) REFERENCES public.inventory_locations(id, inventory_domain) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: review_photos fk_review_photos_review_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_photos
    ADD CONSTRAINT fk_review_photos_review_id FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: reviews fk_reviews_order_item_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_reviews_order_item_id FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: store_inventory_movement_items fk_store_inventory_movement_items_movement_id_inventory_domain; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_inventory_movement_items
    ADD CONSTRAINT fk_store_inventory_movement_items_movement_id_inventory_domain FOREIGN KEY (movement_id, inventory_domain) REFERENCES public.inventory_movements(id, inventory_domain) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: store_inventory_movement_items fk_store_inventory_movement_items_variant_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_inventory_movement_items
    ADD CONSTRAINT fk_store_inventory_movement_items_variant_id FOREIGN KEY (variant_id) REFERENCES public.product_variants(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: zone_blocks fk_zone_blocks_campground_id_zone_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone_blocks
    ADD CONSTRAINT fk_zone_blocks_campground_id_zone_id FOREIGN KEY (campground_id, zone_id) REFERENCES public.campground_zones(campground_id, id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: zone_blocks fk_zone_blocks_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zone_blocks
    ADD CONSTRAINT fk_zone_blocks_created_by FOREIGN KEY (created_by) REFERENCES public.admin_users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict 7AbWotlZqgLjboNPhE21SDcBNmxtPQQqxkQzs2SEMfV0WyhiXnXTDJPV9bZv9xy
