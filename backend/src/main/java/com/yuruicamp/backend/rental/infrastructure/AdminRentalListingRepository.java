package com.yuruicamp.backend.rental.infrastructure;

import java.math.BigDecimal;
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
 * 租借上架（{@code rental_listings}）JDBC 資料存取（W2-04）。
 * Admin rental listing persistence.
 *
 * <p>寫入用 upsert：{@code (campground_id, rental_sku_variant_id)} 是 DB 的
 * UNIQUE 組合，所以同一個組合永遠只會有一筆列，{@code id} 由第一次建立時決定、
 * 之後更新都保留原 id（{@code ON CONFLICT ... DO UPDATE} 不改 id 欄位）。</p>
 */
@Repository
public class AdminRentalListingRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminRentalListingRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	/** 確認營區已有租借庫位對照（同時滿足 rental_listings 兩個 FK）。 */
	public boolean campgroundRentalLocationExists(String campgroundId) {
		Boolean exists = jdbc.queryForObject("""
				SELECT EXISTS (
				    SELECT 1 FROM campground_rental_locations WHERE campground_id = :campgroundId
				)
				""", new MapSqlParameterSource("campgroundId", campgroundId), Boolean.class);
		return Boolean.TRUE.equals(exists);
	}

	/**
	 * 查詢一批租借規格目前全部的 listing（含 inactive），並附上營區名稱與規格 SKU。
	 * 依 campground_id、rental_sku_variant_id 排序，方便前端表格穩定顯示。
	 */
	public List<ListingRow> findListingsForVariants(List<String> rentalSkuVariantIds) {
		if (rentalSkuVariantIds.isEmpty()) {
			return List.of();
		}
		return jdbc.query("""
				SELECT listing.id, listing.campground_id, campground.name AS campground_name,
				       listing.rental_sku_variant_id, variant.sku, variant.specification,
				       listing.price_per_day_weekday, listing.price_per_day_holiday, listing.discount,
				       listing.terrain, listing.description, listing.active,
				       listing.created_at, listing.updated_at
				FROM rental_listings listing
				JOIN campgrounds campground ON campground.id = listing.campground_id
				JOIN rental_sku_variants variant ON variant.id = listing.rental_sku_variant_id
				WHERE listing.rental_sku_variant_id IN (:variantIds)
				ORDER BY listing.campground_id ASC, listing.rental_sku_variant_id ASC
				""", new MapSqlParameterSource("variantIds", rentalSkuVariantIds), this::mapRow);
	}

	/**
	 * Upsert 一筆 listing：不存在就新建（用傳入的 candidateId）；已存在同一個
	 * {@code (campgroundId, rentalSkuVariantId)} 組合就只更新價格／折扣／地形／說明／上下架，
	 * id 保持原值不變。
	 */
	public void upsertListing(
			String candidateId,
			String campgroundId,
			String rentalSkuVariantId,
			BigDecimal pricePerDayWeekday,
			BigDecimal pricePerDayHoliday,
			BigDecimal discount,
			String terrain,
			String description,
			boolean active,
			Instant now) {
		jdbc.update("""
				INSERT INTO rental_listings (
				    id, campground_id, rental_sku_variant_id,
				    price_per_day_weekday, price_per_day_holiday, discount,
				    terrain, description, active, created_at, updated_at)
				VALUES (
				    :id, :campgroundId, :rentalSkuVariantId,
				    :priceWeekday, :priceHoliday, :discount,
				    :terrain, :description, :active, :now, :now)
				ON CONFLICT (campground_id, rental_sku_variant_id) DO UPDATE SET
				    price_per_day_weekday = EXCLUDED.price_per_day_weekday,
				    price_per_day_holiday = EXCLUDED.price_per_day_holiday,
				    discount = EXCLUDED.discount,
				    terrain = EXCLUDED.terrain,
				    description = EXCLUDED.description,
				    active = EXCLUDED.active,
				    updated_at = EXCLUDED.updated_at
				""", new MapSqlParameterSource()
						.addValue("id", candidateId)
						.addValue("campgroundId", campgroundId)
						.addValue("rentalSkuVariantId", rentalSkuVariantId)
						.addValue("priceWeekday", pricePerDayWeekday)
						.addValue("priceHoliday", pricePerDayHoliday)
						.addValue("discount", discount)
						.addValue("terrain", terrain)
						.addValue("description", description)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	/** 把「這次同步請求沒出現」的既有 listing 軟停用；listing 曾被訂過就無法硬刪，只能停用。 */
	public void deactivate(String id, Instant now) {
		jdbc.update("""
				UPDATE rental_listings
				SET active = false,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("now", databaseTime(now)));
	}

	private ListingRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new ListingRow(
				row.getString("id"),
				row.getString("campground_id"),
				row.getString("campground_name"),
				row.getString("rental_sku_variant_id"),
				row.getString("sku"),
				row.getString("specification"),
				row.getBigDecimal("price_per_day_weekday"),
				row.getBigDecimal("price_per_day_holiday"),
				row.getBigDecimal("discount"),
				row.getString("terrain"),
				row.getString("description"),
				row.getBoolean("active"),
				readInstant(row, "created_at"),
				readInstant(row, "updated_at"));
	}

	private Instant readInstant(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return value.atOffset(ZoneOffset.UTC);
	}

	public record ListingRow(
			String id,
			String campgroundId,
			String campgroundName,
			String rentalSkuVariantId,
			String sku,
			String specification,
			BigDecimal pricePerDayWeekday,
			BigDecimal pricePerDayHoliday,
			BigDecimal discount,
			String terrain,
			String description,
			boolean active,
			Instant createdAt,
			Instant updatedAt) {
	}
}
