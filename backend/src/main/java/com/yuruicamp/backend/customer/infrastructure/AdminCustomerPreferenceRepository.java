package com.yuruicamp.backend.customer.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台會員偏好關聯與選項 lookup（W1-05）。
 * Admin customer preference assignments + option dictionary lookup.
 */
@Repository
public class AdminCustomerPreferenceRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCustomerPreferenceRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	/** 列出偏好選項；預設只取 active。 / List options; active-only by default. */
	public List<OptionRow> findAllOptions(boolean includeInactive) {
		String sql = """
				SELECT id, type, code, label, sort_order, active
				FROM preference_options
				"""
				+ (includeInactive ? "" : " WHERE active = true")
				+ " ORDER BY type ASC, sort_order ASC, id ASC";
		return jdbc.query(sql, new MapSqlParameterSource(), this::mapOptionRow);
	}

	/**
	 * 回傳指定 id 中「存在且 active」的選項 id。
	 * Return ids that exist and are active from the requested set.
	 */
	public List<Long> findActiveIds(List<Long> ids) {
		if (ids == null || ids.isEmpty()) {
			return List.of();
		}
		return jdbc.queryForList("""
				SELECT id FROM preference_options
				WHERE id IN (:ids) AND active = true
				ORDER BY id
				""", new MapSqlParameterSource("ids", ids), Long.class);
	}

	/** 刪除不在目標集合內的偏好關聯。 / Remove preferences not in desired set. */
	public void deletePreferencesNotIn(String customerId, List<Long> keepOptionIds) {
		if (keepOptionIds == null || keepOptionIds.isEmpty()) {
			jdbc.update("""
					DELETE FROM customer_preferences WHERE customer_id = :customerId
					""", new MapSqlParameterSource("customerId", customerId));
			return;
		}
		jdbc.update("""
				DELETE FROM customer_preferences
				WHERE customer_id = :customerId AND preference_id NOT IN (:keepOptionIds)
				""", new MapSqlParameterSource()
						.addValue("customerId", customerId)
						.addValue("keepOptionIds", keepOptionIds));
	}

	/** 插入尚不存在的偏好關聯。 / Insert missing preference links. */
	public void insertMissingPreferences(String customerId, List<Long> optionIds) {
		if (optionIds == null || optionIds.isEmpty()) {
			return;
		}
		for (Long optionId : optionIds) {
			jdbc.update("""
					INSERT INTO customer_preferences (customer_id, preference_id)
					VALUES (:customerId, :optionId)
					ON CONFLICT (customer_id, preference_id) DO NOTHING
					""", new MapSqlParameterSource()
							.addValue("customerId", customerId)
							.addValue("optionId", optionId));
		}
	}

	private OptionRow mapOptionRow(ResultSet row, int rowNumber) throws SQLException {
		return new OptionRow(
				row.getLong("id"),
				row.getString("type"),
				row.getString("code"),
				row.getString("label"),
				row.getInt("sort_order"),
				row.getBoolean("active"));
	}

	public record OptionRow(
			long id,
			String type,
			String code,
			String label,
			int sortOrder,
			boolean active) {
	}
}
