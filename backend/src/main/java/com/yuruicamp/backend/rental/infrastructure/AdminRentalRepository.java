package com.yuruicamp.backend.rental.infrastructure;

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
 * 租借 SKU 寫入用 JDBC：直接操作 {@code equipment_items}、{@code rental_skus}、
 * {@code rental_sku_variants} 三張表（W2-03）。
 *
 * <p>命名說明給新手：這裡的「SKU」＝{@code rental_skus}（跟 equipment_items 一對一，
 * 只有一個 status），「規格／variant」＝{@code rental_sku_variants}（同一 SKU 底下的
 * 顏色／尺寸／版本，各自有自己的 status，也是真正拿去下單的最小單位）。</p>
 */
@Repository
public class AdminRentalRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminRentalRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	// ------------------------------------------------------------------
	// equipment_items（裝備共用主檔：名稱／分類／品牌／描述）
	// ------------------------------------------------------------------

	/** 新增裝備主檔；租借 SKU 一律新建 item，不重用既有 item（見 Request 註解）。 */
	public void insertEquipmentItem(
			String id,
			long categoryId,
			String brandId,
			String name,
			String description,
			boolean active,
			Instant now) {
		jdbc.update("""
				INSERT INTO equipment_items (id, category_id, brand_id, name, description, active, created_at, updated_at)
				VALUES (:id, :categoryId, :brandId, :name, :description, :active, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("categoryId", categoryId)
						.addValue("brandId", brandId)
						.addValue("name", name)
						.addValue("description", description)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	/** 更新裝備主檔的展示欄位；不動 active（租借上下架只用 rental_skus.status）。 */
	public void updateEquipmentItem(
			String itemId,
			long categoryId,
			String brandId,
			String name,
			String description,
			Instant now) {
		jdbc.update("""
				UPDATE equipment_items
				SET category_id = :categoryId,
				    brand_id = :brandId,
				    name = :name,
				    description = :description,
				    updated_at = :now
				WHERE id = :itemId
				""", new MapSqlParameterSource()
						.addValue("itemId", itemId)
						.addValue("categoryId", categoryId)
						.addValue("brandId", brandId)
						.addValue("name", name)
						.addValue("description", description)
						.addValue("now", databaseTime(now)));
	}

	// ------------------------------------------------------------------
	// rental_skus（租借 SKU＝與 equipment_items 一對一的狀態容器）
	// ------------------------------------------------------------------

	public void insertRentalSku(String id, String itemId, String status, Instant now) {
		jdbc.update("""
				INSERT INTO rental_skus (id, item_id, status, created_at, updated_at)
				VALUES (:id, :itemId, :status, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("itemId", itemId)
						.addValue("status", status)
						.addValue("now", databaseTime(now)));
	}

	public void updateRentalSkuStatus(String id, String status, Instant now) {
		jdbc.update("""
				UPDATE rental_skus
				SET status = :status,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("status", status)
						.addValue("now", databaseTime(now)));
	}

	/** 一般查詢（不鎖列）；找不到回 {@code null}。 */
	public RentalSkuRow findById(String id) {
		List<RentalSkuRow> rows = jdbc.query("""
				SELECT id, item_id, status, created_at, updated_at
				FROM rental_skus
				WHERE id = :id
				""", new MapSqlParameterSource("id", id), this::mapRentalSkuRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	/** 更新／activate／deactivate 前先鎖列，避免併發衝突。 */
	public RentalSkuRow lockById(String id) {
		List<RentalSkuRow> rows = jdbc.query("""
				SELECT id, item_id, status, created_at, updated_at
				FROM rental_skus
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRentalSkuRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	// ------------------------------------------------------------------
	// rental_sku_variants（規格：顏色／尺寸／版本，各自有 status）
	// ------------------------------------------------------------------

	public List<VariantRow> findVariantsByRentalSkuId(String rentalSkuId) {
		return jdbc.query("""
				SELECT id, rental_sku_id, sku, color, size, specification, status, created_at, updated_at
				FROM rental_sku_variants
				WHERE rental_sku_id = :rentalSkuId
				ORDER BY id ASC
				""", new MapSqlParameterSource("rentalSkuId", rentalSkuId), this::mapVariantRow);
	}

	/** 上架前檢查：至少要有一個 active 規格才能把整個 SKU 打成 active。 */
	public long countActiveVariants(String rentalSkuId) {
		Long count = jdbc.queryForObject("""
				SELECT count(*) FROM rental_sku_variants
				WHERE rental_sku_id = :rentalSkuId AND status = 'active'
				""", new MapSqlParameterSource("rentalSkuId", rentalSkuId), Long.class);
		return count == null ? 0L : count;
	}

	public boolean existsBySku(String sku) {
		Boolean exists = jdbc.queryForObject("""
				SELECT EXISTS (SELECT 1 FROM rental_sku_variants WHERE sku = :sku)
				""", new MapSqlParameterSource("sku", sku), Boolean.class);
		return Boolean.TRUE.equals(exists);
	}

	public boolean existsBySkuAndIdNot(String sku, String variantId) {
		Boolean exists = jdbc.queryForObject("""
				SELECT EXISTS (
				    SELECT 1 FROM rental_sku_variants WHERE sku = :sku AND id <> :variantId
				)
				""", new MapSqlParameterSource()
						.addValue("sku", sku)
						.addValue("variantId", variantId),
				Boolean.class);
		return Boolean.TRUE.equals(exists);
	}

	public void insertVariant(
			String id,
			String rentalSkuId,
			String sku,
			String color,
			String size,
			String specification,
			String status,
			Instant now) {
		jdbc.update("""
				INSERT INTO rental_sku_variants
				    (id, rental_sku_id, sku, color, size, specification, status, created_at, updated_at)
				VALUES (:id, :rentalSkuId, :sku, :color, :size, :specification, :status, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("rentalSkuId", rentalSkuId)
						.addValue("sku", sku)
						.addValue("color", color)
						.addValue("size", size)
						.addValue("specification", specification)
						.addValue("status", status)
						.addValue("now", databaseTime(now)));
	}

	/** 更新既有規格內容，也用來把「Request 沒送出」的舊規格改成 inactive（不硬刪）。 */
	public void updateVariant(
			String id,
			String sku,
			String color,
			String size,
			String specification,
			String status,
			Instant now) {
		jdbc.update("""
				UPDATE rental_sku_variants
				SET sku = :sku,
				    color = :color,
				    size = :size,
				    specification = :specification,
				    status = :status,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("sku", sku)
						.addValue("color", color)
						.addValue("size", size)
						.addValue("specification", specification)
						.addValue("status", status)
						.addValue("now", databaseTime(now)));
	}

	/** 只改 status（給「未出現的舊規格 → inactive」的最小更新用）。 */
	public void updateVariantStatus(String id, String status, Instant now) {
		jdbc.update("""
				UPDATE rental_sku_variants
				SET status = :status,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("status", status)
						.addValue("now", databaseTime(now)));
	}

	private RentalSkuRow mapRentalSkuRow(ResultSet row, int rowNumber) throws SQLException {
		return new RentalSkuRow(
				row.getString("id"),
				row.getString("item_id"),
				row.getString("status"),
				readInstant(row, "created_at"),
				readInstant(row, "updated_at"));
	}

	private VariantRow mapVariantRow(ResultSet row, int rowNumber) throws SQLException {
		return new VariantRow(
				row.getString("id"),
				row.getString("rental_sku_id"),
				row.getString("sku"),
				row.getString("color"),
				row.getString("size"),
				row.getString("specification"),
				row.getString("status"),
				readInstant(row, "created_at"),
				readInstant(row, "updated_at"));
	}

	private Instant readInstant(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return value.atOffset(ZoneOffset.UTC);
	}

	public record RentalSkuRow(
			String id,
			String itemId,
			String status,
			Instant createdAt,
			Instant updatedAt) {
	}

	public record VariantRow(
			String id,
			String rentalSkuId,
			String sku,
			String color,
			String size,
			String specification,
			String status,
			Instant createdAt,
			Instant updatedAt) {
	}
}
