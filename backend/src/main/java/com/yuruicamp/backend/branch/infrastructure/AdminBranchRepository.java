package com.yuruicamp.backend.branch.infrastructure;

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
 * 用途：後台門市主檔 JDBC 存取（ADM-W2-07）。
 * 核心重點：
 *   - 後台永遠讀「全部」門市（含停用），過濾邏輯只在公開 API（見 {@code BranchRepository}）。
 *   - 刪除前必須先確認沒有 `orders.pickup_branch_id`／`inventory_locations.branch_id` 引用，
 *     否則 Service 層要擋下來改成 409，引導改用軟停用（`active=false`）。
 * Admin branch persistence; hard-delete safety checks live here as simple COUNT queries.
 */
@Repository
public class AdminBranchRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminBranchRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	private static final String SELECT_COLUMNS = """
			SELECT id, name, address, phone, latitude, longitude, map_query,
			       business_hours, image_url, active, created_at, updated_at
			FROM branches
			""";

	/** 後台列表：依 id 排序，含停用門市。 / Admin list: all branches ordered by id. */
	public List<BranchRow> findAll() {
		return jdbc.query(SELECT_COLUMNS + " ORDER BY id ASC", new MapSqlParameterSource(), this::mapRow);
	}

	public BranchRow findById(String id) {
		List<BranchRow> rows = jdbc.query(SELECT_COLUMNS + " WHERE id = :id",
				new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	/** FOR UPDATE 鎖定列，避免更新／刪除競態。 / Lock row for update/delete. */
	public BranchRow lockById(String id) {
		List<BranchRow> rows = jdbc.query(SELECT_COLUMNS + " WHERE id = :id FOR UPDATE",
				new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public void insert(String id, String name, String address, String phone,
			BigDecimal latitude, BigDecimal longitude, String mapQuery,
			String businessHours, String imageUrl, boolean active, Instant now) {
		jdbc.update("""
				INSERT INTO branches (
				    id, name, address, phone, latitude, longitude, map_query,
				    business_hours, image_url, active, created_at, updated_at
				)
				VALUES (
				    :id, :name, :address, :phone, :latitude, :longitude, :mapQuery,
				    :businessHours, :imageUrl, :active, :now, :now
				)
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("name", name)
						.addValue("address", address)
						.addValue("phone", phone)
						.addValue("latitude", latitude)
						.addValue("longitude", longitude)
						.addValue("mapQuery", mapQuery)
						.addValue("businessHours", businessHours)
						.addValue("imageUrl", imageUrl)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	public void update(String id, String name, String address, String phone,
			BigDecimal latitude, BigDecimal longitude, String mapQuery,
			String businessHours, String imageUrl, boolean active, Instant now) {
		jdbc.update("""
				UPDATE branches
				SET name = :name,
				    address = :address,
				    phone = :phone,
				    latitude = :latitude,
				    longitude = :longitude,
				    map_query = :mapQuery,
				    business_hours = :businessHours,
				    image_url = :imageUrl,
				    active = :active,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("name", name)
						.addValue("address", address)
						.addValue("phone", phone)
						.addValue("latitude", latitude)
						.addValue("longitude", longitude)
						.addValue("mapQuery", mapQuery)
						.addValue("businessHours", businessHours)
						.addValue("imageUrl", imageUrl)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	public void delete(String id) {
		// branch_features 有 ON DELETE CASCADE，硬刪門市時會一併清掉；
		// orders.pickup_branch_id／inventory_locations.branch_id 是 ON DELETE RESTRICT，
		// 所以真的有引用時這裡會直接被 DB 擋下來（Service 層會先用下面兩個 COUNT 主動擋更友善的 409）。
		jdbc.update("DELETE FROM branches WHERE id = :id", new MapSqlParameterSource("id", id));
	}

	/** 有多少張訂單把這間門市設為取貨門市。 / Count orders picking up at this branch. */
	public long countOrderReferences(String branchId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM orders WHERE pickup_branch_id = :branchId
				""", new MapSqlParameterSource("branchId", branchId), Long.class);
		return count == null ? 0L : count;
	}

	/** 有多少個庫位掛在這間門市底下。 / Count inventory locations under this branch. */
	public long countInventoryLocationReferences(String branchId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM inventory_locations WHERE branch_id = :branchId
				""", new MapSqlParameterSource("branchId", branchId), Long.class);
		return count == null ? 0L : count;
	}

	private BranchRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new BranchRow(
				row.getString("id"),
				row.getString("name"),
				row.getString("address"),
				row.getString("phone"),
				row.getBigDecimal("latitude"),
				row.getBigDecimal("longitude"),
				row.getString("map_query"),
				row.getString("business_hours"),
				row.getString("image_url"),
				row.getBoolean("active"),
				time(row, "created_at"),
				time(row, "updated_at"));
	}

	private Instant time(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record BranchRow(
			String id,
			String name,
			String address,
			String phone,
			BigDecimal latitude,
			BigDecimal longitude,
			String mapQuery,
			String businessHours,
			String imageUrl,
			boolean active,
			Instant createdAt,
			Instant updatedAt) {
	}
}
