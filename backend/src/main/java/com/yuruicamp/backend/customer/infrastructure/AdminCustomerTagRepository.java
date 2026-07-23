package com.yuruicamp.backend.customer.infrastructure;

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
 * 後台會員標籤池資料存取（customer_tags + assignment 計數）。
 * Admin customer tag pool persistence.
 */
@Repository
public class AdminCustomerTagRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCustomerTagRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	/** 依啟用狀態列出標籤；預設只取 active。 / List tags; active-only by default. */
	public List<TagRow> findAll(boolean includeInactive) {
		String sql = """
				SELECT id, name, color, sort_order, active, created_at, updated_at
				FROM customer_tags
				"""
				+ (includeInactive ? "" : " WHERE active = true")
				+ " ORDER BY sort_order ASC, id ASC";
		return jdbc.query(sql, new MapSqlParameterSource(), this::mapRow);
	}

	public TagRow findById(long id) {
		List<TagRow> rows = jdbc.query("""
				SELECT id, name, color, sort_order, active, created_at, updated_at
				FROM customer_tags
				WHERE id = :id
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	/** FOR UPDATE 鎖定列，避免刪除／改名競態。 / Lock row for update. */
	public TagRow lockById(long id) {
		List<TagRow> rows = jdbc.query("""
				SELECT id, name, color, sort_order, active, created_at, updated_at
				FROM customer_tags
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRow);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public long insert(String name, String color, int sortOrder, boolean active, Instant now) {
		GeneratedKeyHolder keyHolder = new GeneratedKeyHolder();
		jdbc.update("""
				INSERT INTO customer_tags (name, color, sort_order, active, created_at, updated_at)
				VALUES (:name, :color, :sortOrder, :active, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("name", name)
						.addValue("color", color)
						.addValue("sortOrder", sortOrder)
						.addValue("active", active)
						.addValue("now", databaseTime(now)),
				keyHolder,
				new String[] { "id" });
		Number key = keyHolder.getKey();
		if (key == null) {
			throw new IllegalStateException("Failed to insert customer_tags row");
		}
		return key.longValue();
	}

	public void update(long id, String name, String color, int sortOrder, boolean active, Instant now) {
		jdbc.update("""
				UPDATE customer_tags
				SET name = :name,
				    color = :color,
				    sort_order = :sortOrder,
				    active = :active,
				    updated_at = :now
				WHERE id = :id
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("name", name)
						.addValue("color", color)
						.addValue("sortOrder", sortOrder)
						.addValue("active", active)
						.addValue("now", databaseTime(now)));
	}

	public void delete(long id) {
		jdbc.update(
				"DELETE FROM customer_tags WHERE id = :id",
				new MapSqlParameterSource("id", id));
	}

	/** 計算有多少會員掛了此標籤。 / Count assignments for a tag. */
	public long countAssignments(long tagId) {
		Long count = jdbc.queryForObject("""
				SELECT count(*) FROM customer_tag_assignments WHERE tag_id = :tagId
				""", new MapSqlParameterSource("tagId", tagId), Long.class);
		return count == null ? 0L : count;
	}

	/**
	 * 回傳指定 id 中「存在且 active」的標籤 id 集合。
	 * Return ids that exist and are active from the requested set.
	 */
	public List<Long> findActiveIds(List<Long> ids) {
		if (ids == null || ids.isEmpty()) {
			return List.of();
		}
		return jdbc.queryForList("""
				SELECT id FROM customer_tags
				WHERE id IN (:ids) AND active = true
				ORDER BY id
				""", new MapSqlParameterSource("ids", ids), Long.class);
	}

	/** 讀取會員目前全部指派（含已停用標籤的殘留列）。 / Current assignment tag ids. */
	public List<Long> findAssignedTagIds(String customerId) {
		return jdbc.queryForList("""
				SELECT tag_id FROM customer_tag_assignments
				WHERE customer_id = :customerId
				ORDER BY tag_id
				""", new MapSqlParameterSource("customerId", customerId), Long.class);
	}

	/** 刪除不在目標集合內的指派。 / Remove assignments not in desired set. */
	public void deleteAssignmentsNotIn(String customerId, List<Long> keepTagIds) {
		if (keepTagIds == null || keepTagIds.isEmpty()) {
			jdbc.update("""
					DELETE FROM customer_tag_assignments WHERE customer_id = :customerId
					""", new MapSqlParameterSource("customerId", customerId));
			return;
		}
		jdbc.update("""
				DELETE FROM customer_tag_assignments
				WHERE customer_id = :customerId AND tag_id NOT IN (:keepTagIds)
				""", new MapSqlParameterSource()
						.addValue("customerId", customerId)
						.addValue("keepTagIds", keepTagIds));
	}

	/** 插入尚不存在的指派（略過已存在）。 / Insert missing assignments. */
	public void insertMissingAssignments(String customerId, List<Long> tagIds) {
		if (tagIds == null || tagIds.isEmpty()) {
			return;
		}
		for (Long tagId : tagIds) {
			jdbc.update("""
					INSERT INTO customer_tag_assignments (customer_id, tag_id)
					VALUES (:customerId, :tagId)
					ON CONFLICT (customer_id, tag_id) DO NOTHING
					""", new MapSqlParameterSource()
							.addValue("customerId", customerId)
							.addValue("tagId", tagId));
		}
	}

	private TagRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new TagRow(
				row.getLong("id"),
				row.getString("name"),
				row.getString("color"),
				row.getInt("sort_order"),
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

	public record TagRow(
			long id,
			String name,
			String color,
			int sortOrder,
			boolean active,
			Instant createdAt,
			Instant updatedAt) {
	}
}
