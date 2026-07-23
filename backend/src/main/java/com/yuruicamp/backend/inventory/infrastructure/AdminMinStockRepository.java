package com.yuruicamp.backend.inventory.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台最低庫存閾值資料存取（商城／租借兩張表）。
 * Admin min-stock persistence for store and rental tables.
 */
@Repository
public class AdminMinStockRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminMinStockRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	/** 查詢商城最低庫存。 / Query store min-stocks. */
	public List<MinStockRow> findStore(String variantId, String locationId, String productId) {
		StringBuilder sql = new StringBuilder("""
				SELECT 'store' AS inventory_domain,
				       ms.variant_id,
				       pv.product_id,
				       ms.location_id,
				       ms.minimum_quantity,
				       ms.updated_at
				FROM product_variant_min_stocks ms
				JOIN product_variants pv ON pv.id = ms.variant_id
				WHERE 1 = 1
				""");
		MapSqlParameterSource params = new MapSqlParameterSource();
		if (variantId != null && !variantId.isBlank()) {
			sql.append(" AND ms.variant_id = :variantId");
			params.addValue("variantId", variantId);
		}
		if (locationId != null && !locationId.isBlank()) {
			sql.append(" AND ms.location_id = :locationId");
			params.addValue("locationId", locationId);
		}
		if (productId != null && !productId.isBlank()) {
			sql.append(" AND pv.product_id = :productId");
			params.addValue("productId", productId);
		}
		sql.append(" ORDER BY pv.product_id, ms.variant_id, ms.location_id");
		return jdbc.query(sql.toString(), params, this::mapRow);
	}

	/** 查詢租借最低庫存。 / Query rental min-stocks. */
	public List<MinStockRow> findRental(String variantId, String locationId, String productId) {
		StringBuilder sql = new StringBuilder("""
				SELECT 'rental' AS inventory_domain,
				       ms.rental_sku_variant_id AS variant_id,
				       rsv.rental_sku_id AS product_id,
				       ms.location_id,
				       ms.minimum_quantity,
				       ms.updated_at
				FROM rental_sku_variant_min_stocks ms
				JOIN rental_sku_variants rsv ON rsv.id = ms.rental_sku_variant_id
				WHERE 1 = 1
				""");
		MapSqlParameterSource params = new MapSqlParameterSource();
		if (variantId != null && !variantId.isBlank()) {
			sql.append(" AND ms.rental_sku_variant_id = :variantId");
			params.addValue("variantId", variantId);
		}
		if (locationId != null && !locationId.isBlank()) {
			sql.append(" AND ms.location_id = :locationId");
			params.addValue("locationId", locationId);
		}
		if (productId != null && !productId.isBlank()) {
			sql.append(" AND rsv.rental_sku_id = :productId");
			params.addValue("productId", productId);
		}
		sql.append(" ORDER BY rsv.rental_sku_id, ms.rental_sku_variant_id, ms.location_id");
		return jdbc.query(sql.toString(), params, this::mapRow);
	}

	/** 讀取單筆商城閾值（含 product_id）。 / Read one store row. */
	public MinStockRow findStoreOne(String variantId, String locationId) {
		List<MinStockRow> rows = findStore(variantId, locationId, null);
		return rows.isEmpty() ? null : rows.get(0);
	}

	/** 讀取單筆租借閾值。 / Read one rental row. */
	public MinStockRow findRentalOne(String variantId, String locationId) {
		List<MinStockRow> rows = findRental(variantId, locationId, null);
		return rows.isEmpty() ? null : rows.get(0);
	}

	/**
	 * Upsert 商城閾值；不碰 inventory_stocks。
	 * Upsert store threshold; never touches inventory_stocks.
	 */
	public void upsertStore(String variantId, String locationId, int minimumQuantity, Instant now) {
		jdbc.update("""
				INSERT INTO product_variant_min_stocks (
				    variant_id, location_id, minimum_quantity, inventory_domain, updated_at)
				VALUES (:variantId, :locationId, :minimumQuantity, 'store', :now)
				ON CONFLICT (variant_id, location_id) DO UPDATE SET
				    minimum_quantity = EXCLUDED.minimum_quantity,
				    updated_at = EXCLUDED.updated_at
				""", new MapSqlParameterSource()
						.addValue("variantId", variantId)
						.addValue("locationId", locationId)
						.addValue("minimumQuantity", minimumQuantity)
						.addValue("now", databaseTime(now)));
	}

	/**
	 * Upsert 租借閾值；不碰 rental_sku_variant_stocks。
	 * Upsert rental threshold; never touches rental stocks.
	 */
	public void upsertRental(String variantId, String locationId, int minimumQuantity, Instant now) {
		jdbc.update("""
				INSERT INTO rental_sku_variant_min_stocks (
				    rental_sku_variant_id, location_id, minimum_quantity, updated_at)
				VALUES (:variantId, :locationId, :minimumQuantity, :now)
				ON CONFLICT (rental_sku_variant_id, location_id) DO UPDATE SET
				    minimum_quantity = EXCLUDED.minimum_quantity,
				    updated_at = EXCLUDED.updated_at
				""", new MapSqlParameterSource()
						.addValue("variantId", variantId)
						.addValue("locationId", locationId)
						.addValue("minimumQuantity", minimumQuantity)
						.addValue("now", databaseTime(now)));
	}

	/** 規格是否存在（商城）。 / Whether store variant exists. */
	public boolean storeVariantExists(String variantId) {
		Long count = jdbc.queryForObject(
				"SELECT count(*) FROM product_variants WHERE id = :id",
				new MapSqlParameterSource("id", variantId),
				Long.class);
		return count != null && count > 0;
	}

	/** 規格是否存在（租借）。 / Whether rental variant exists. */
	public boolean rentalVariantExists(String variantId) {
		Long count = jdbc.queryForObject(
				"SELECT count(*) FROM rental_sku_variants WHERE id = :id",
				new MapSqlParameterSource("id", variantId),
				Long.class);
		return count != null && count > 0;
	}

	/** 讀取啟用中庫位（含 domain）。 / Active location with domain. */
	public LocationRow findActiveLocation(String locationId) {
		List<LocationRow> rows = jdbc.query("""
				SELECT id, inventory_domain, active
				FROM inventory_locations
				WHERE id = :id
				""", new MapSqlParameterSource("id", locationId), (row, n) -> new LocationRow(
						row.getString("id"),
						row.getString("inventory_domain"),
						row.getBoolean("active")));
		return rows.isEmpty() ? null : rows.get(0);
	}

	/** 讀取商城 on_hand（驗收用：確認閾值寫入未改庫存）。 / Store on_hand for IT assert. */
	public Integer findStoreOnHand(String variantId, String locationId) {
		List<Integer> rows = jdbc.query("""
				SELECT on_hand_quantity
				FROM inventory_stocks
				WHERE variant_id = :variantId AND location_id = :locationId
				""", new MapSqlParameterSource()
						.addValue("variantId", variantId)
						.addValue("locationId", locationId),
				(row, n) -> row.getInt("on_hand_quantity"));
		return rows.isEmpty() ? null : rows.get(0);
	}

	private MinStockRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new MinStockRow(
				row.getString("inventory_domain"),
				row.getString("variant_id"),
				row.getString("product_id"),
				row.getString("location_id"),
				row.getInt("minimum_quantity"),
				time(row, "updated_at"));
	}

	private Instant time(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record MinStockRow(
			String inventoryDomain,
			String variantId,
			String productId,
			String locationId,
			int minimumQuantity,
			Instant updatedAt) {
	}

	public record LocationRow(String id, String inventoryDomain, boolean active) {
	}
}
