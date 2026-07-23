package com.yuruicamp.backend.review.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MemberReviewRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public MemberReviewRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	/**
	 * 鎖定本人訂單明細，讓「檢查重複＋新增」在併發請求下維持一致。
	 */
	public PurchasedItem findPurchasedItemForUpdate(long orderItemId) {
		List<PurchasedItem> rows = jdbc.query("""
				SELECT item.id AS order_item_id, item.order_id, order_header.customer_id,
				       order_header.status::text AS order_status,
				       item.product_id, item.variant_id, item.sku_snapshot,
				       item.product_name_snapshot, order_header.buyer_name_snapshot
				FROM order_items item
				JOIN orders order_header ON order_header.id = item.order_id
				WHERE item.id = :orderItemId
				FOR UPDATE OF item
				""", new MapSqlParameterSource()
				.addValue("orderItemId", orderItemId), this::mapPurchasedItem);
		return rows.isEmpty() ? null : rows.get(0);
	}

	public boolean existsByOrderItemId(long orderItemId) {
		Long count = jdbc.queryForObject(
				"SELECT count(*) FROM reviews WHERE order_item_id = :orderItemId",
				new MapSqlParameterSource("orderItemId", orderItemId),
				Long.class);
		return count != null && count > 0;
	}

	public void insert(String id, long orderItemId, int rating, String comment, Instant createdAt) {
		jdbc.update("""
				INSERT INTO reviews (id, order_item_id, rating, comment, created_at)
				VALUES (:id, :orderItemId, :rating, :comment, :createdAt)
				""", new MapSqlParameterSource()
				.addValue("id", id)
				.addValue("orderItemId", orderItemId)
				.addValue("rating", rating)
				.addValue("comment", comment)
				.addValue("createdAt", OffsetDateTime.ofInstant(createdAt, java.time.ZoneOffset.UTC)));
	}

	public void insertPhotos(String reviewId, List<String> urls) {
		for (int index = 0; index < urls.size(); index++) {
			jdbc.update("""
					INSERT INTO review_photos (review_id, sort_order, url)
					VALUES (:reviewId, :sortOrder, :url)
					""", new MapSqlParameterSource()
					.addValue("reviewId", reviewId)
					.addValue("sortOrder", index)
					.addValue("url", urls.get(index)));
		}
	}

	public List<MemberReviewRow> findAllForCustomer(String customerId) {
		List<MemberReviewRow> rows = jdbc.query("""
				SELECT review.id, review.order_item_id, item.order_id, order_header.customer_id,
				       item.product_id, item.variant_id, item.sku_snapshot,
				       item.product_name_snapshot, order_header.buyer_name_snapshot,
				       review.rating, review.comment, review.created_at
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				JOIN orders order_header ON order_header.id = item.order_id
				WHERE order_header.customer_id = :customerId
				ORDER BY review.created_at DESC, review.id ASC
				""", new MapSqlParameterSource("customerId", customerId), this::mapReview);

		Map<String, List<String>> photos = findPhotos(rows.stream().map(MemberReviewRow::id).toList());
		List<MemberReviewRow> result = new ArrayList<>();
		for (MemberReviewRow row : rows) {
			result.add(row.withPhotos(photos.getOrDefault(row.id(), List.of())));
		}
		return result;
	}

	public MemberReviewRow findByIdForCustomer(String reviewId, String customerId) {
		List<MemberReviewRow> rows = jdbc.query("""
				SELECT review.id, review.order_item_id, item.order_id, order_header.customer_id,
				       item.product_id, item.variant_id, item.sku_snapshot,
				       item.product_name_snapshot, order_header.buyer_name_snapshot,
				       review.rating, review.comment, review.created_at
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				JOIN orders order_header ON order_header.id = item.order_id
				WHERE review.id = :reviewId AND order_header.customer_id = :customerId
				FOR UPDATE OF review
				""", new MapSqlParameterSource()
				.addValue("reviewId", reviewId)
				.addValue("customerId", customerId), this::mapReview);
		if (rows.isEmpty()) {
			return null;
		}
		return rows.getFirst().withPhotos(findPhotos(List.of(reviewId)).getOrDefault(reviewId, List.of()));
	}

	public void update(String reviewId, int rating, String comment) {
		jdbc.update("""
				UPDATE reviews SET rating = :rating, comment = :comment WHERE id = :reviewId
				""", new MapSqlParameterSource()
				.addValue("reviewId", reviewId)
				.addValue("rating", rating)
				.addValue("comment", comment));
	}

	public void replacePhotos(String reviewId, List<String> urls) {
		jdbc.update("DELETE FROM review_photos WHERE review_id = :reviewId",
				new MapSqlParameterSource("reviewId", reviewId));
		insertPhotos(reviewId, urls);
	}

	public void delete(String reviewId) {
		jdbc.update("DELETE FROM reviews WHERE id = :reviewId",
				new MapSqlParameterSource("reviewId", reviewId));
	}

	private Map<String, List<String>> findPhotos(List<String> ids) {
		Map<String, List<String>> result = new HashMap<>();
		if (ids.isEmpty()) {
			return result;
		}
		jdbc.query("""
				SELECT review_id, url
				FROM review_photos
				WHERE review_id IN (:ids)
				ORDER BY sort_order ASC
				""", new MapSqlParameterSource("ids", ids), row -> {
			result.computeIfAbsent(row.getString("review_id"), ignored -> new ArrayList<>())
					.add(row.getString("url"));
		});
		return result;
	}

	private PurchasedItem mapPurchasedItem(ResultSet row, int rowNumber) throws SQLException {
		return new PurchasedItem(
				row.getLong("order_item_id"),
				row.getString("order_id"),
				row.getString("customer_id"),
				row.getString("order_status"),
				row.getString("product_id"),
				row.getString("variant_id"),
				row.getString("sku_snapshot"),
				row.getString("product_name_snapshot"),
				row.getString("buyer_name_snapshot"));
	}

	private MemberReviewRow mapReview(ResultSet row, int rowNumber) throws SQLException {
		return new MemberReviewRow(
				row.getString("id"),
				row.getLong("order_item_id"),
				row.getString("order_id"),
				row.getString("customer_id"),
				row.getString("product_id"),
				row.getString("variant_id"),
				row.getString("sku_snapshot"),
				row.getString("product_name_snapshot"),
				row.getString("buyer_name_snapshot"),
				row.getInt("rating"),
				row.getString("comment"),
				row.getObject("created_at", OffsetDateTime.class).toInstant(),
				List.of());
	}

	public record PurchasedItem(
			long orderItemId,
			String orderId,
			String customerId,
			String orderStatus,
			String productId,
			String variantId,
			String sku,
			String productName,
			String buyerName) {
	}

	public record MemberReviewRow(
			String id,
			long orderItemId,
			String orderId,
			String customerId,
			String productId,
			String variantId,
			String sku,
			String productName,
			String buyerName,
			int rating,
			String comment,
			Instant createdAt,
			List<String> photos) {

		public MemberReviewRow withPhotos(List<String> nextPhotos) {
			return new MemberReviewRow(
					id, orderItemId, orderId, customerId, productId, variantId, sku,
					productName, buyerName, rating, comment, createdAt, List.copyOf(nextPhotos));
		}
	}
}
