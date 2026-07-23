package com.yuruicamp.backend.review.api;

import java.time.Instant;
import java.util.List;

/**
 * 會員自己的已購商品評價。
 */
public record MemberReviewResponse(
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
		List<String> photos,
		boolean verifiedPurchase,
		Instant createdAt) {
}
