package com.yuruicamp.backend.catalog.infrastructure;

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
 * 品牌主檔 JDBC（W2-02）。
 * Admin brands persistence.
 */
@Repository
public class AdminBrandRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminBrandRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public List<BrandRow> findAll() {
		return jdbc.query("""
				SELECT id, name, logo_url, sort_order, created_at, updated_at
				FROM brands
				ORDER BY sort_order ASC, id ASC
				""", new MapSqlParameterSource(), this::mapRow);
	}

	public BrandRow findById(String id) {
		List<BrandRow> rows = jdbc.query("""
				SELECT id, name, logo_url, sort_order, created_at, updated_at
				FROM brands
				WHERE id = :id
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public BrandRow lockById(String id) {
		List<BrandRow> rows = jdbc.query("""
				SELECT id, name, logo_url, sort_order, created_at, updated_at
				FROM brands
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public void insert(String id, String name, String logoUrl, int sortOrder, Instant now) {
		jdbc.update("""
				INSERT INTO brands (id, name, logo_url, sort_order, created_at, updated_at)
				VALUES (:id, :name, :logoUrl, :sortOrder, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("name", name)
						.addValue("logoUrl", logoUrl)
						.addValue("sortOrder", sortOrder)
						.addValue("now", databaseTime(now)));
	}

	public void update(String id, String name, String logoUrl, int sortOrder, Instant now) {
		jdbc.update("""
				UPDATE brands
				SET name = :name,
				    logo_url = :logoUrl,
				    sort_order = :sortOrder,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("name", name)
						.addValue("logoUrl", logoUrl)
						.addValue("sortOrder", sortOrder)
						.addValue("now", databaseTime(now)));
	}

	public void delete(String id) {
		jdbc.update(
				"DELETE FROM brands WHERE id = :id",
				new MapSqlParameterSource("id", id));
	}

	public long countEquipmentReferences(String brandId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM equipment_items WHERE brand_id = :id
				""", new MapSqlParameterSource("id", brandId), Long.class);
		return count == null ? 0L : count;
	}

	private BrandRow mapRow(ResultSet rs, int rowNum) throws SQLException {
		return new BrandRow(
				rs.getString("id"),
				rs.getString("name"),
				rs.getString("logo_url"),
				rs.getInt("sort_order"),
				readInstant(rs, "created_at"),
				readInstant(rs, "updated_at"));
	}

	private Instant readInstant(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return value.atOffset(ZoneOffset.UTC);
	}

	public record BrandRow(
			String id,
			String name,
			String logoUrl,
			int sortOrder,
			Instant createdAt,
			Instant updatedAt) {
	}
}
