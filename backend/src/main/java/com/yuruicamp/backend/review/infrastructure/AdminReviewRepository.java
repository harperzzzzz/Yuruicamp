package com.yuruicamp.backend.review.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台評論讀模型與硬刪（兩段式分頁＋photos 另查）。
 * Admin review read model and hard delete.
 */
@Repository
public class AdminReviewRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminReviewRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public IdPage findIds(
			int page,
			int size,
			String query,
			String productId,
			Integer rating,
			Instant createdFrom,
			Instant createdTo,
			String sortColumn,
			String sortDirection) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("query", "%" + query.toLowerCase(Locale.ROOT) + "%")
				.addValue("productId", productId)
				.addValue("rating", rating)
				.addValue("createdFrom", createdFrom == null ? null : databaseTime(createdFrom))
				.addValue("createdTo", createdTo == null ? null : databaseTime(createdTo))
				.addValue("limit", size)
				.addValue("offset", page * size);

		StringBuilder where = new StringBuilder("""
				WHERE (
				    :query = '%%'
				    OR lower(review.id) LIKE :query
				    OR lower(COALESCE(order_header.buyer_name_snapshot, '')) LIKE :query
				    OR lower(COALESCE(item.product_name_snapshot, '')) LIKE :query
				    OR lower(COALESCE(review.comment, '')) LIKE :query
				)
				""");
		if (productId != null && !productId.isBlank()) {
			where.append(" AND item.product_id = :productId");
		}
		if (rating != null) {
			where.append(" AND review.rating = :rating");
		}
		if (createdFrom != null) {
			where.append(" AND review.created_at >= :createdFrom");
		}
		if (createdTo != null) {
			where.append(" AND review.created_at <= :createdTo");
		}

		String from = """
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				JOIN orders order_header ON order_header.id = item.order_id
				""";

		Long total = jdbc.queryForObject("SELECT count(*) " + from + where, parameters, Long.class);
		List<String> ids = jdbc.queryForList(
				"SELECT review.id " + from + where
						+ " ORDER BY " + sortColumn + " " + sortDirection + ", review.id ASC"
						+ " LIMIT :limit OFFSET :offset",
				parameters,
				String.class);

		return new IdPage(ids, total == null ? 0L : total);
	}

	public List<ReviewRow> findByIds(List<String> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		List<ReviewRow> rows = jdbc.query("""
				SELECT review.id, review.order_item_id, item.order_id, order_header.customer_id,
				       item.product_id, item.variant_id, item.sku_snapshot,
				       item.product_name_snapshot, order_header.buyer_name_snapshot,
				       customer.avatar_url, review.rating, review.comment, review.created_at
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				JOIN orders order_header ON order_header.id = item.order_id
				LEFT JOIN customers customer ON customer.id = order_header.customer_id
				WHERE review.id IN (:ids)
				""", new MapSqlParameterSource("ids", ids), this::mapRow);

		Map<String, ReviewRow> byId = new HashMap<>();
		rows.forEach(row -> byId.put(row.id(), row));
		List<ReviewRow> ordered = new ArrayList<>();
		for (String id : ids) {
			ReviewRow row = byId.get(id);
			if (row != null) {
				ordered.add(row);
			}
		}
		return ordered;
	}

	public ReviewRow findById(String id) {
		List<ReviewRow> rows = findByIds(List.of(id));
		return rows.isEmpty() ? null : rows.get(0);
	}

	public Map<String, List<String>> findPhotos(List<String> reviewIds) {
		Map<String, List<String>> result = new HashMap<>();
		if (reviewIds.isEmpty()) {
			return result;
		}
		jdbc.query("""
				SELECT review_id, url
				FROM review_photos
				WHERE review_id IN (:ids)
				ORDER BY sort_order ASC, url ASC
				""", new MapSqlParameterSource("ids", reviewIds), row -> {
			String reviewId = row.getString("review_id");
			result.computeIfAbsent(reviewId, ignored -> new ArrayList<>())
					.add(row.getString("url"));
		});
		return result;
	}

	public boolean exists(String id) {
		Long count = jdbc.queryForObject(
				"SELECT count(*) FROM reviews WHERE id = :id",
				new MapSqlParameterSource("id", id),
				Long.class);
		return count != null && count > 0;
	}

	/** 硬刪；photos 依 FK CASCADE。 / Hard delete; photos cascade. */
	public void delete(String id) {
		jdbc.update(
				"DELETE FROM reviews WHERE id = :id",
				new MapSqlParameterSource("id", id));
	}

	private ReviewRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new ReviewRow(
				row.getString("id"),
				row.getLong("order_item_id"),
				row.getString("order_id"),
				row.getString("customer_id"),
				row.getString("product_id"),
				row.getString("variant_id"),
				row.getString("sku_snapshot"),
				row.getString("product_name_snapshot"),
				row.getString("buyer_name_snapshot"),
				row.getString("avatar_url"),
				row.getInt("rating"),
				row.getString("comment"),
				time(row, "created_at"));
	}

	private Instant time(ResultSet row, String column) throws SQLException {
		return row.getObject(column, OffsetDateTime.class).toInstant();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record IdPage(List<String> ids, long totalElements) {
	}

	public record ReviewRow(
			String id,
			long orderItemId,
			String orderId,
			String customerId,
			String productId,
			String variantId,
			String sku,
			String productName,
			String buyerName,
			String buyerAvatar,
			int rating,
			String comment,
			Instant createdAt) {
	}
}
