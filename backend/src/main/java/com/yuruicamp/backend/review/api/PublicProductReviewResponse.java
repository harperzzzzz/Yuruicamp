package com.yuruicamp.backend.review.api;

import java.time.Instant;
import java.util.List;

/** Public verified-purchase review. Private customer and order identifiers are excluded. */
public record PublicProductReviewResponse(
		String id,
		String buyerName,
		String productName,
		int rating,
		String comment,
		List<String> photos,
		boolean verifiedPurchase,
		Instant createdAt) {
}
