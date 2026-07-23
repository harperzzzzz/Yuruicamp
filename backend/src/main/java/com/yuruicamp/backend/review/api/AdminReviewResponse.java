package com.yuruicamp.backend.review.api;

import java.time.Instant;
import java.util.List;

/**
 * 後台評論詳情／列表項目（扁平，對齊 Admin 前端卡片）。
 * Admin review list/detail item.
 */
public record AdminReviewResponse(
		String id,
		Long orderItemId,
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
		List<String> photos,
		boolean verifiedPurchase,
		Instant createdAt) {
}
