package com.yuruicamp.backend.coupon.infrastructure;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
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
 * 後台優惠券資料存取，列表先分頁取 ID，再依固定順序組回完整資料。
 */
@Repository
public class AdminCouponRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCouponRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public IdPage findIds(
			int page,
			int size,
			String query,
			String status,
			String category,
			String sortColumn,
			String sortDirection) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("query", "%" + query.toLowerCase(java.util.Locale.ROOT) + "%")
				.addValue("limit", size)
				.addValue("offset", page * size);
		StringBuilder where = new StringBuilder(" WHERE (lower(code) LIKE :query OR lower(name) LIKE :query)");
		appendFilter(where, parameters, "status", status, "status::text");
		appendFilter(where, parameters, "category", category, "category::text");

		long totalElements = jdbc.queryForObject(
				"SELECT count(*) FROM coupons" + where,
				parameters,
				Long.class);
		List<Long> ids = jdbc.queryForList(
				"SELECT id FROM coupons" + where
						+ " ORDER BY " + sortColumn + " " + sortDirection + ", id DESC"
						+ " LIMIT :limit OFFSET :offset",
				parameters,
				Long.class);

		return new IdPage(ids, totalElements);
	}

	public List<CouponRow> findByIds(List<Long> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		List<CouponRow> rows = jdbc.query("""
				SELECT id, code, name, discount_type, discount_value, minimum_amount,
				       issue_quantity, claimed_quantity, valid_from, valid_until,
				       status::text, category::text, created_at, updated_at
				FROM coupons
				WHERE id IN (:ids)
				""", new MapSqlParameterSource("ids", ids), this::mapRow);
		Map<Long, CouponRow> rowsById = new HashMap<>();
		rows.forEach(row -> rowsById.put(row.id(), row));
		List<CouponRow> result = new ArrayList<>();
		for (Long id : ids) {
			CouponRow row = rowsById.get(id);
			if (row != null) {
				result.add(row);
			}
		}

		return result;
	}

	public CouponRow findById(long id) {
		List<CouponRow> rows = jdbc.query("""
				SELECT id, code, name, discount_type, discount_value, minimum_amount,
				       issue_quantity, claimed_quantity, valid_from, valid_until,
				       status::text, category::text, created_at, updated_at
				FROM coupons
				WHERE id = :id
				""", new MapSqlParameterSource("id", id), this::mapRow);

		return rows.isEmpty() ? null : rows.getFirst();
	}

	public CouponRow lockById(long id) {
		List<CouponRow> rows = jdbc.query("""
				SELECT id, code, name, discount_type, discount_value, minimum_amount,
				       issue_quantity, claimed_quantity, valid_from, valid_until,
				       status::text, category::text, created_at, updated_at
				FROM coupons
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRow);

		return rows.isEmpty() ? null : rows.getFirst();
	}

	public long insert(CouponWrite write, Instant now) {
		MapSqlParameterSource parameters = parameters(write, now);

		return jdbc.queryForObject("""
				INSERT INTO coupons (
				    code, name, discount_type, discount_value, minimum_amount,
				    issue_quantity, claimed_quantity, valid_from, valid_until,
				    status, category, created_at, updated_at)
				VALUES (
				    :code, :name, :discountType, :discountValue, :minimumAmount,
				    :issueQuantity, 0, :validFrom, :validUntil,
				    CAST(:status AS coupon_status), CAST(:category AS coupon_category), :now, :now)
				RETURNING id
				""", parameters, Long.class);
	}

	public void update(long id, CouponWrite write, Instant now) {
		MapSqlParameterSource parameters = parameters(write, now)
				.addValue("id", id);
		jdbc.update("""
				UPDATE coupons
				SET name = :name,
				    discount_type = :discountType,
				    discount_value = :discountValue,
				    minimum_amount = :minimumAmount,
				    issue_quantity = :issueQuantity,
				    valid_from = :validFrom,
				    valid_until = :validUntil,
				    status = CAST(:status AS coupon_status),
				    category = CAST(:category AS coupon_category),
				    updated_at = :now
				WHERE id = :id
				""", parameters);
	}

	public boolean hasClaims(long id) {
		Integer count = jdbc.queryForObject(
				"SELECT count(*) FROM coupon_claims WHERE coupon_id = :id",
				new MapSqlParameterSource("id", id),
				Integer.class);

		return count != null && count > 0;
	}

	public void delete(long id) {
		jdbc.update("DELETE FROM coupons WHERE id = :id", new MapSqlParameterSource("id", id));
	}

	private MapSqlParameterSource parameters(CouponWrite write, Instant now) {
		return new MapSqlParameterSource()
				.addValue("code", write.code())
				.addValue("name", write.name())
				.addValue("discountType", write.discountType())
				.addValue("discountValue", write.discountValue())
				.addValue("minimumAmount", write.minimumAmount())
				.addValue("issueQuantity", write.issueQuantity())
				.addValue("validFrom", databaseTime(write.validFrom()))
				.addValue("validUntil", databaseTime(write.validUntil()))
				.addValue("status", write.status())
				.addValue("category", write.category())
				.addValue("now", databaseTime(now));
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

	private CouponRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new CouponRow(
				row.getLong("id"),
				row.getString("code"),
				row.getString("name"),
				row.getString("discount_type"),
				row.getBigDecimal("discount_value"),
				row.getBigDecimal("minimum_amount"),
				row.getInt("issue_quantity"),
				row.getInt("claimed_quantity"),
				time(row, "valid_from"),
				time(row, "valid_until"),
				row.getString("status"),
				row.getString("category"),
				time(row, "created_at"),
				time(row, "updated_at"));
	}

	private Instant time(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record IdPage(List<Long> ids, long totalElements) {
	}

	public record CouponRow(
			long id,
			String code,
			String name,
			String discountType,
			BigDecimal discountValue,
			BigDecimal minimumAmount,
			int issueQuantity,
			int claimedQuantity,
			Instant validFrom,
			Instant validUntil,
			String status,
			String category,
			Instant createdAt,
			Instant updatedAt) {
	}

	public record CouponWrite(
			String code,
			String name,
			String discountType,
			BigDecimal discountValue,
			BigDecimal minimumAmount,
			int issueQuantity,
			Instant validFrom,
			Instant validUntil,
			String status,
			String category) {
	}
}
