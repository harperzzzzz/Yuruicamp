package com.yuruicamp.backend.inventory.api;

import java.time.Instant;

/**
 * 庫位主檔回應（W2-06）。
 * Admin inventory location response.
 */
public record AdminInventoryLocationResponse(
		String id,
		String code,
		String inventoryDomain,
		String type,
		String branchId,
		String name,
		boolean active,
		Instant createdAt,
		Instant updatedAt) {
}
