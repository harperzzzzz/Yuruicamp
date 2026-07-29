package com.yuruicamp.backend.catalog.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Repository;

/**
 * 分類主檔 JDBC（W2-01）。
 * Admin product_categories persistence.
 */
@Repository
public class AdminCategoryRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCategoryRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public List<CategoryRow> findAll() {
		return jdbc.query("""
				SELECT id, code, name, sort_order, created_at, updated_at
				FROM product_categories
				ORDER BY sort_order ASC, id ASC
				""", new MapSqlParameterSource(), this::mapRow);
	}

	public CategoryRow findById(long id) {
		List<CategoryRow> rows = jdbc.query("""
				SELECT id, code, name, sort_order, created_at, updated_at
				FROM product_categories
				WHERE id = :id
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public CategoryRow lockById(long id) {
		List<CategoryRow> rows = jdbc.query("""
				SELECT id, code, name, sort_order, created_at, updated_at
				FROM product_categories
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public long insert(String code, String name, int sortOrder, Instant now) {
		GeneratedKeyHolder keyHolder = new GeneratedKeyHolder();
		jdbc.update("""
				INSERT INTO product_categories (code, name, sort_order, created_at, updated_at)
				VALUES (:code, :name, :sortOrder, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("code", code)
						.addValue("name", name)
						.addValue("sortOrder", sortOrder)
						.addValue("now", databaseTime(now)),
				keyHolder,
				new String[] { "id" });
		Number key = keyHolder.getKey();
		if (key == null) {
			throw new IllegalStateException("Failed to insert product_categories row");
		}
		return key.longValue();
	}

	public void update(long id, String code, String name, int sortOrder, Instant now) {
		jdbc.update("""
				UPDATE product_categories
				SET code = :code,
				    name = :name,
				    sort_order = :sortOrder,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("code", code)
						.addValue("name", name)
						.addValue("sortOrder", sortOrder)
						.addValue("now", databaseTime(now)));
	}

	public void delete(long id) {
		jdbc.update(
				"DELETE FROM product_categories WHERE id = :id",
				new MapSqlParameterSource("id", id));
	}

	/** 被裝備主檔引用的筆數（刪除前檢查）。 / Count equipment refs before delete. */
	public long countEquipmentReferences(long categoryId) {
		Long count = jdbc.queryForObject("""
				SELECT COUNT(*) FROM equipment_items WHERE category_id = :id
				""", new MapSqlParameterSource("id", categoryId), Long.class);
		return count == null ? 0L : count;
	}

	private CategoryRow mapRow(ResultSet rs, int rowNum) throws SQLException {
		return new CategoryRow(
				rs.getLong("id"),
				rs.getString("code"),
				rs.getString("name"),
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

	public record CategoryRow(
			long id,
			String code,
			String name,
			int sortOrder,
			Instant createdAt,
			Instant updatedAt) {
	}
}
