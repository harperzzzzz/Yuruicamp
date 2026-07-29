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
 * 庫位主檔 JDBC（W2-06）。
 * Admin inventory_locations persistence.
 */
@Repository
public class AdminInventoryLocationRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminInventoryLocationRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public List<LocationRow> findAll(boolean includeInactive) {
		String sql = """
				SELECT id, code, inventory_domain, type, branch_id, name, active, created_at, updated_at
				FROM inventory_locations
				"""
				+ (includeInactive ? "" : " WHERE active = true")
				+ " ORDER BY inventory_domain, type, name, id";
		return jdbc.query(sql, new MapSqlParameterSource(), this::mapRow);
	}

	public LocationRow findById(String id) {
		List<LocationRow> rows = jdbc.query("""
				SELECT id, code, inventory_domain, type, branch_id, name, active, created_at, updated_at
				FROM inventory_locations
				WHERE id = :id
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public LocationRow lockById(String id) {
		List<LocationRow> rows = jdbc.query("""
				SELECT id, code, inventory_domain, type, branch_id, name, active, created_at, updated_at
				FROM inventory_locations
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public boolean branchExists(String branchId) {
		Long count = jdbc.queryForObject(
				"SELECT COUNT(*) FROM branches WHERE id = :id",
				new MapSqlParameterSource("id", branchId),
				Long.class);
		return count != null && count > 0;
	}

	public void insert(
			String id,
			String code,
			String inventoryDomain,
			String type,
			String branchId,
			String name,
			boolean active,
			Instant now) {
		jdbc.update("""
				INSERT INTO inventory_locations (
				    id, code, inventory_domain, type, branch_id, name, active, created_at, updated_at)
				VALUES (
				    :id, :code, :inventoryDomain, :type, :branchId, :name, :active, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("code", code)
						.addValue("inventoryDomain", inventoryDomain)
						.addValue("type", type)
						.addValue("branchId", branchId)
						.addValue("name", name)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	public void update(String id, String name, boolean active, Instant now) {
		jdbc.update("""
				UPDATE inventory_locations
				SET name = :name,
				    active = :active,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("name", name)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	public void delete(String id) {
		jdbc.update(
				"DELETE FROM inventory_locations WHERE id = :id",
				new MapSqlParameterSource("id", id));
	}

	/** 商店庫存 on_hand 合計。 / Sum store on-hand at location. */
	public long sumStoreOnHand(String locationId) {
		Long sum = jdbc.queryForObject("""
				SELECT COALESCE(SUM(on_hand_quantity), 0)
				FROM inventory_stocks
				WHERE location_id = :id
				""", new MapSqlParameterSource("id", locationId), Long.class);
		return sum == null ? 0L : sum;
	}

	/** 租借庫存 on_hand 合計。 / Sum rental on-hand at location. */
	public long sumRentalOnHand(String locationId) {
		Long sum = jdbc.queryForObject("""
				SELECT COALESCE(SUM(on_hand_quantity), 0)
				FROM rental_sku_variant_stocks
				WHERE location_id = :id
				""", new MapSqlParameterSource("id", locationId), Long.class);
		return sum == null ? 0L : sum;
	}

	public long countActiveProductReservations(String locationId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM product_stock_reservations
				WHERE location_id = :id AND status = 'active'
				""", new MapSqlParameterSource("id", locationId), Long.class);
		return count == null ? 0L : count;
	}

	public long countActiveRentalReservations(String locationId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM rental_stock_reservations
				WHERE location_id = :id AND status = 'active'
				""", new MapSqlParameterSource("id", locationId), Long.class);
		return count == null ? 0L : count;
	}

	public long countMovementReferences(String locationId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM inventory_movements
				WHERE source_location_id = :id OR destination_location_id = :id
				""", new MapSqlParameterSource("id", locationId), Long.class);
		return count == null ? 0L : count;
	}

	private LocationRow mapRow(ResultSet rs, int rowNum) throws SQLException {
		return new LocationRow(
				rs.getString("id"),
				rs.getString("code"),
				rs.getString("inventory_domain"),
				rs.getString("type"),
				rs.getString("branch_id"),
				rs.getString("name"),
				rs.getBoolean("active"),
				readInstant(rs, "created_at"),
				readInstant(rs, "updated_at"));
	}

	private Instant readInstant(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return value.atOffset(ZoneOffset.UTC);
	}

	public record LocationRow(
			String id,
			String code,
			String inventoryDomain,
			String type,
			String branchId,
			String name,
			boolean active,
			Instant createdAt,
			Instant updatedAt) {
	}
}
