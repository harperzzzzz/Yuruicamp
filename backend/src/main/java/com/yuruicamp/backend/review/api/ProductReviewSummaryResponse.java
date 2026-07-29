package com.yuruicamp.backend.review.api;

import java.math.BigDecimal;
import java.util.Map;

/** Aggregate rating statistics for one product. */
public record ProductReviewSummaryResponse(
		long totalCount,
		BigDecimal averageRating,
		Map<Integer, Long> ratingCounts) {
}
