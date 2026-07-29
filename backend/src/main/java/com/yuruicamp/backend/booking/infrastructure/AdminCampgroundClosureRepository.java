package com.yuruicamp.backend.booking.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台營區公休資料存取，所有查詢都保留營區與建立者顯示名稱。
 */
@Repository
public class AdminCampgroundClosureRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCampgroundClosureRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public IdPage findIds(
			int page,
			int size,
			String query,
			String campgroundId,
			String closureType,
			String sortColumn,
			String sortDirection) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("query", "%" + query.toLowerCase(java.util.Locale.ROOT) + "%")
				.addValue("limit", size)
				.addValue("offset", page * size);
		StringBuilder where = new StringBuilder("""
				 WHERE (lower(closure.reason) LIKE :query
				    OR lower(campground.name) LIKE :query)
				""");
		appendFilter(where, parameters, "campgroundId", campgroundId, "closure.campground_id");
		appendFilter(where, parameters, "closureType", closureType, "closure.closure_type");

		long totalElements = jdbc.queryForObject(
				"SELECT count(*) FROM campground_closures closure "
						+ "JOIN campgrounds campground ON campground.id = closure.campground_id" + where,
				parameters,
				Long.class);
		List<Long> ids = jdbc.queryForList(
				"SELECT closure.id FROM campground_closures closure "
						+ "JOIN campgrounds campground ON campground.id = closure.campground_id" + where
						+ " ORDER BY " + sortColumn + " " + sortDirection + ", closure.id DESC"
						+ " LIMIT :limit OFFSET :offset",
				parameters,
				Long.class);

		return new IdPage(ids, totalElements);
	}

	public List<ClosureRow> findByIds(List<Long> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		List<ClosureRow> rows = jdbc.query("""
				SELECT closure.id, closure.campground_id, campground.name AS campground_name,
				       closure.closure_type, closure.start_date, closure.end_date, closure.weekday,
				       closure.effective_from, closure.effective_to, closure.reason,
				       closure.created_by, employee.name AS created_by_name,
				       closure.created_at, closure.updated_at
				FROM campground_closures closure
				JOIN campgrounds campground ON campground.id = closure.campground_id
				JOIN admin_users employee ON employee.id = closure.created_by
				WHERE closure.id IN (:ids)
				""", new MapSqlParameterSource("ids", ids), this::mapRow);
		Map<Long, ClosureRow> rowsById = new HashMap<>();
		rows.forEach(row -> rowsById.put(row.id(), row));
		List<ClosureRow> result = new ArrayList<>();
		for (Long id : ids) {
			ClosureRow row = rowsById.get(id);
			if (row != null) {
				result.add(row);
			}
		}

		return result;
	}

	public ClosureRow findById(long id) {
		List<ClosureRow> rows = findByIds(List.of(id));

		return rows.isEmpty() ? null : rows.getFirst();
	}

	public ClosureRow lockById(long id) {
		List<ClosureRow> rows = jdbc.query("""
				SELECT closure.id, closure.campground_id, campground.name AS campground_name,
				       closure.closure_type, closure.start_date, closure.end_date, closure.weekday,
				       closure.effective_from, closure.effective_to, closure.reason,
				       closure.created_by, employee.name AS created_by_name,
				       closure.created_at, closure.updated_at
				FROM campground_closures closure
				JOIN campgrounds campground ON campground.id = closure.campground_id
				JOIN admin_users employee ON employee.id = closure.created_by
				WHERE closure.id = :id
				FOR UPDATE OF closure
				""", new MapSqlParameterSource("id", id), this::mapRow);

		return rows.isEmpty() ? null : rows.getFirst();
	}

	public String findActiveCampgroundName(String id) {
		List<String> names = jdbc.queryForList("""
				SELECT name
				FROM campgrounds
				WHERE id = :id AND active = true
				""", new MapSqlParameterSource("id", id), String.class);

		return names.isEmpty() ? null : names.getFirst();
	}

	public long insert(ClosureWrite write, String createdBy, Instant now) {
		MapSqlParameterSource parameters = parameters(write, now)
				.addValue("createdBy", createdBy);

		return jdbc.queryForObject("""
				INSERT INTO campground_closures (
				    campground_id, closure_type, start_date, end_date, weekday,
				    effective_from, effective_to, reason, created_by, created_at, updated_at)
				VALUES (
				    :campgroundId, :closureType, :startDate, :endDate, :weekday,
				    :effectiveFrom, :effectiveTo, :reason, :createdBy, :now, :now)
				RETURNING id
				""", parameters, Long.class);
	}

	public void update(long id, ClosureWrite write, Instant now) {
		MapSqlParameterSource parameters = parameters(write, now)
				.addValue("id", id);
		jdbc.update("""
				UPDATE campground_closures
				SET closure_type = :closureType,
				    start_date = :startDate,
				    end_date = :endDate,
				    weekday = :weekday,
				    effective_from = :effectiveFrom,
				    effective_to = :effectiveTo,
				    reason = :reason,
				    updated_at = :now
				WHERE id = :id
				""", parameters);
	}

	public void delete(long id) {
		jdbc.update(
				"DELETE FROM campground_closures WHERE id = :id",
				new MapSqlParameterSource("id", id));
	}

	private MapSqlParameterSource parameters(ClosureWrite write, Instant now) {
		return new MapSqlParameterSource()
				.addValue("campgroundId", write.campgroundId())
				.addValue("closureType", write.closureType())
				.addValue("startDate", write.startDate())
				.addValue("endDate", write.endDate())
				.addValue("weekday", write.weekday())
				.addValue("effectiveFrom", write.effectiveFrom())
				.addValue("effectiveTo", write.effectiveTo())
				.addValue("reason", write.reason())
				.addValue("now", OffsetDateTime.ofInstant(now, ZoneOffset.UTC));
	}

	private void appendFilter(
			StringBuilder where,
			MapSqlParameterSource parameters,
			String parameterName,
			String value,
			String column) {
		if (!value.isBlank()) {
			where.append(" AND ").append(column).append(" = :").append(parameterName);
			parameters.addValue(parameterName, value);
		}
	}

	private ClosureRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new ClosureRow(
				row.getLong("id"),
				row.getString("campground_id"),
				row.getString("campground_name"),
				row.getString("closure_type"),
				row.getObject("start_date", LocalDate.class),
				row.getObject("end_date", LocalDate.class),
				row.getObject("weekday", Integer.class),
				row.getObject("effective_from", LocalDate.class),
				row.getObject("effective_to", LocalDate.class),
				row.getString("reason"),
				row.getString("created_by"),
				row.getString("created_by_name"),
				row.getObject("created_at", OffsetDateTime.class).toInstant(),
				row.getObject("updated_at", OffsetDateTime.class).toInstant());
	}

	public record IdPage(List<Long> ids, long totalElements) {
	}

	public record ClosureRow(
			long id,
			String campgroundId,
			String campgroundName,
			String closureType,
			LocalDate startDate,
			LocalDate endDate,
			Integer weekday,
			LocalDate effectiveFrom,
			LocalDate effectiveTo,
			String reason,
			String createdBy,
			String createdByName,
			Instant createdAt,
			Instant updatedAt) {
	}

	public record ClosureWrite(
			String campgroundId,
			String closureType,
			LocalDate startDate,
			LocalDate endDate,
			Integer weekday,
			LocalDate effectiveFrom,
			LocalDate effectiveTo,
			String reason) {
	}
}
