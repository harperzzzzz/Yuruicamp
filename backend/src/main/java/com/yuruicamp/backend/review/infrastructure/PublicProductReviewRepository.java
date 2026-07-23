package com.yuruicamp.backend.review.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class PublicProductReviewRepository {

	private final JdbcClient jdbc;

	public PublicProductReviewRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	public List<PublicReviewRow> findPage(
			String productId,
			int size,
			int offset,
			String orderBy,
			Integer rating,
			boolean hasPhotos) {
		return jdbc.sql("""
				SELECT review.id, order_header.buyer_name_snapshot, item.product_name_snapshot,
				       review.rating, review.comment, review.created_at
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				JOIN orders order_header ON order_header.id = item.order_id
				WHERE item.product_id = :productId
				  AND (:rating = 0 OR review.rating = :rating)
				  AND (
				      :hasPhotos = false
				      OR EXISTS (SELECT 1 FROM review_photos photo WHERE photo.review_id = review.id)
				  )
				ORDER BY %s, review.id ASC
				LIMIT :size OFFSET :offset
				""".formatted(orderBy))
				.param("productId", productId)
				.param("rating", rating == null ? 0 : rating)
				.param("hasPhotos", hasPhotos)
				.param("size", size)
				.param("offset", offset)
				.query(this::mapRow)
				.list();
	}

	public long countFiltered(String productId, Integer rating, boolean hasPhotos) {
		Long total = jdbc.sql("""
				SELECT count(*)
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				WHERE item.product_id = :productId
				  AND (:rating = 0 OR review.rating = :rating)
				  AND (
				      :hasPhotos = false
				      OR EXISTS (SELECT 1 FROM review_photos photo WHERE photo.review_id = review.id)
				  )
				""")
				.param("productId", productId)
				.param("rating", rating == null ? 0 : rating)
				.param("hasPhotos", hasPhotos)
				.query(Long.class)
				.single();

		return total == null ? 0 : total;
	}

	public RatingSummary summarize(String productId) {
		return jdbc.sql("""
				SELECT count(*) AS total_count,
				       COALESCE(round(avg(review.rating), 2), 0) AS average_rating,
				       count(*) FILTER (WHERE review.rating = 1) AS rating_1,
				       count(*) FILTER (WHERE review.rating = 2) AS rating_2,
				       count(*) FILTER (WHERE review.rating = 3) AS rating_3,
				       count(*) FILTER (WHERE review.rating = 4) AS rating_4,
				       count(*) FILTER (WHERE review.rating = 5) AS rating_5
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				WHERE item.product_id = :productId
				""")
				.param("productId", productId)
				.query((rs, rowNum) -> new RatingSummary(
						rs.getLong("total_count"),
						rs.getBigDecimal("average_rating"),
						Map.of(
								1, rs.getLong("rating_1"),
								2, rs.getLong("rating_2"),
								3, rs.getLong("rating_3"),
								4, rs.getLong("rating_4"),
								5, rs.getLong("rating_5"))))
				.single();
	}

	public Map<String, List<String>> findPhotos(List<String> reviewIds) {
		if (reviewIds.isEmpty()) {
			return Map.of();
		}
		Map<String, List<String>> result = new LinkedHashMap<>();
		List<PhotoRow> rows = jdbc.sql("""
				SELECT review_id, url
				FROM review_photos
				WHERE review_id IN (:reviewIds)
				ORDER BY review_id, sort_order
				""")
				.param("reviewIds", reviewIds)
				.query((rs, rowNum) -> new PhotoRow(rs.getString("review_id"), rs.getString("url")))
				.list();
		rows.forEach(row -> result.computeIfAbsent(row.reviewId(), ignored -> new ArrayList<>()).add(row.url()));
		return result;
	}

	private PublicReviewRow mapRow(ResultSet rs, int rowNum) throws SQLException {
		OffsetDateTime createdAt = rs.getObject("created_at", OffsetDateTime.class);
		return new PublicReviewRow(
				rs.getString("id"),
				rs.getString("buyer_name_snapshot"),
				rs.getString("product_name_snapshot"),
				rs.getInt("rating"),
				rs.getString("comment"),
				createdAt == null ? null : createdAt.toInstant());
	}

	public record PublicReviewRow(
			String id,
			String buyerName,
			String productName,
			int rating,
			String comment,
			Instant createdAt) {
	}

	public record RatingSummary(long totalCount, java.math.BigDecimal averageRating, Map<Integer, Long> ratingCounts) {
	}

	private record PhotoRow(String reviewId, String url) {
	}
}
