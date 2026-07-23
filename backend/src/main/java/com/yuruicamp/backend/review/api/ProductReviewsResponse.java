package com.yuruicamp.backend.review.api;

import java.util.List;

/** Public review page payload. Pagination metadata remains in the common response envelope. */
public record ProductReviewsResponse(
		List<PublicProductReviewResponse> items,
		ProductReviewSummaryResponse summary) {
}
