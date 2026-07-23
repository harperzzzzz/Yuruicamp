package com.yuruicamp.backend.catalog.infrastructure;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * {@code equipment_specifications}／{@code equipment_tags} JDBC 資料存取（W2-04）。
 * Admin equipment specs/tags persistence, keyed by {@code equipment_items.id}.
 *
 * <p>兩張表都掛在 {@code equipment_items} 底下，同時被商城商品與租借規格共用；
 * 這支 Repository 只認 {@code itemId}，不管這個裝備目前是商城商品還是租借 SKU
 * ——這正是「依 itemId 更新，不分商城／租借」的契約規則在程式碼上的體現。</p>
 */
@Repository
public class AdminEquipmentAttributeRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminEquipmentAttributeRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	// ------------------------------------------------------------------
	// equipment_specifications（規格鍵值對）
	// ------------------------------------------------------------------

	public List<SpecRow> findSpecs(String itemId) {
		return jdbc.query("""
				SELECT spec_key, value
				FROM equipment_specifications
				WHERE item_id = :itemId
				ORDER BY spec_key ASC
				""", new MapSqlParameterSource("itemId", itemId),
				(row, rowNumber) -> new SpecRow(row.getString("spec_key"), row.getString("value")));
	}

	/** 整組取代前先清空舊資料；跟商品圖片 replace 的寫法一致（先刪光再重建）。 */
	public void deleteAllSpecs(String itemId) {
		jdbc.update(
				"DELETE FROM equipment_specifications WHERE item_id = :itemId",
				new MapSqlParameterSource("itemId", itemId));
	}

	public void insertSpec(String itemId, String key, String value, Instant now) {
		jdbc.update("""
				INSERT INTO equipment_specifications (item_id, spec_key, value, created_at, updated_at)
				VALUES (:itemId, :key, :value, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("itemId", itemId)
						.addValue("key", key)
						.addValue("value", value)
						.addValue("now", databaseTime(now)));
	}

	// ------------------------------------------------------------------
	// equipment_tags（查詢／特色標籤）
	// ------------------------------------------------------------------

	public List<String> findTags(String itemId) {
		return jdbc.queryForList("""
				SELECT tag FROM equipment_tags
				WHERE item_id = :itemId
				ORDER BY tag ASC
				""", new MapSqlParameterSource("itemId", itemId), String.class);
	}

	public void deleteAllTags(String itemId) {
		jdbc.update(
				"DELETE FROM equipment_tags WHERE item_id = :itemId",
				new MapSqlParameterSource("itemId", itemId));
	}

	public void insertTag(String itemId, String tag, Instant now) {
		jdbc.update("""
				INSERT INTO equipment_tags (item_id, tag, created_at, updated_at)
				VALUES (:itemId, :tag, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("itemId", itemId)
						.addValue("tag", tag)
						.addValue("now", databaseTime(now)));
	}

	private OffsetDateTime databaseTime(Instant value) {
		return value.atOffset(ZoneOffset.UTC);
	}

	/** 一筆規格鍵值列。 */
	public record SpecRow(String key, String value) {
	}
}
