package com.yuruicamp.backend.inventory.api;

import java.time.Instant;
import java.util.List;

/**
 * 後台庫存異動表頭與明細的完整回應。
 */
public record AdminInventoryMovementResponse(
		long id,
		String movementNo,
		String inventoryDomain,
		String movementType,
		String status,
		String sourceLocationId,
		String sourceLocationName,
		String destinationLocationId,
		String destinationLocationName,
		String employeeId,
		String employeeName,
		String reason,
		Instant occurredAt,
		Instant postedAt,
		Instant createdAt,
		Instant updatedAt,
		List<AdminInventoryMovementItemResponse> items) {
}
