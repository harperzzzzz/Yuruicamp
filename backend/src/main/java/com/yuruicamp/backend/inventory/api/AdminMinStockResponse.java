package com.yuruicamp.backend.inventory.api;

import java.time.Instant;

/**
 * 後台最低庫存閾值一筆（variant × location）。
 * One admin min-stock threshold row.
 */
public record AdminMinStockResponse(
		String inventoryDomain,
		String variantId,
		String productId,
		String locationId,
		int minimumQuantity,
		Instant updatedAt) {
}
