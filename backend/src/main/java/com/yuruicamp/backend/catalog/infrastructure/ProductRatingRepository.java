package com.yuruicamp.backend.catalog.infrastructure;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class ProductRatingRepository {

	private final JdbcClient jdbc;

	public ProductRatingRepository(JdbcClient jdbc) {
		this.jdbc = jdbc;
	}

	public Map<String, ProductRating> findByProductIds(List<String> productIds) {
		if (productIds.isEmpty()) {
			return Map.of();
		}
		return jdbc.sql("""
				SELECT item.product_id,
				       round(avg(review.rating), 1) AS rating,
				       count(*) AS review_count
				FROM reviews review
				JOIN order_items item ON item.id = review.order_item_id
				WHERE item.product_id IN (:productIds)
				GROUP BY item.product_id
				""")
				.param("productIds", productIds)
				.query((rs, rowNum) -> new ProductRating(
						rs.getString("product_id"),
						rs.getBigDecimal("rating"),
						rs.getLong("review_count")))
				.list()
				.stream()
				.collect(Collectors.toMap(ProductRating::productId, rating -> rating));
	}

	public record ProductRating(String productId, BigDecimal rating, long reviewCount) {
		public static ProductRating empty(String productId) {
			return new ProductRating(productId, BigDecimal.ZERO, 0);
		}
	}
}
