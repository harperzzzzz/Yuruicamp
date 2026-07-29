package com.yuruicamp.backend.rental.api;

import java.time.Instant;
import java.util.List;

/**
 * 後台租借 SKU 完整回應，以 {@code equipment_items} → {@code rental_skus} →
 * {@code rental_sku_variants} 組合。
 * Admin rental SKU full response.
 */
public record AdminRentalResponse(
		String id,
		String itemId,
		String status,
		String name,
		Long categoryId,
		String category,
		String brandId,
		String brand,
		String description,
		List<AdminRentalVariantResponse> variants,
		Instant createdAt,
		Instant updatedAt) {
}
