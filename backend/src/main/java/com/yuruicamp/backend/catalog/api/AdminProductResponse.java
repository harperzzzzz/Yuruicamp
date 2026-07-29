package com.yuruicamp.backend.catalog.api;

import java.time.Instant;
import java.util.List;

/**
 * 後台商品完整回應，以資料庫正規化模型組合，不回傳前端 Mock 的租借或衍生寫入欄位。
 */
public record AdminProductResponse(
		String id,
		String itemId,
		String status,
		String name,
		Long categoryId,
		String category,
		String brandId,
		String brand,
		String description,
		String image,
		List<AdminProductImageResponse> images,
		String price,
		int totalOnHand,
		int totalReserved,
		int totalAvailable,
		List<AdminProductVariantResponse> variants,
		Instant createdAt,
		Instant updatedAt) {
}
