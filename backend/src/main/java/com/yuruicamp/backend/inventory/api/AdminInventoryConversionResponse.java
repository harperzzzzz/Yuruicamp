package com.yuruicamp.backend.inventory.api;

import java.time.Instant;

/**
 * 跨領域庫存轉換的完整回應：成對的 store／rental 異動表頭資訊＋轉換配對本身。
 * {@code status} 取自兩張異動表頭（兩者永遠同步變化，過帳／作廢都在同一交易內一起處理）。
 */
public record AdminInventoryConversionResponse(
		long id,
		String idempotencyKey,
		String status,
		int quantity,
		String reason,
		String sourceLocationId,
		String sourceLocationName,
		String destinationLocationId,
		String destinationLocationName,
		String sourceVariantId,
		String sourceVariantSku,
		String sourceVariantName,
		String destinationRentalVariantId,
		String destinationVariantSku,
		String destinationVariantName,
		long sourceMovementId,
		String sourceMovementNo,
		long destinationMovementId,
		String destinationMovementNo,
		String employeeId,
		String employeeName,
		Instant occurredAt,
		Instant postedAt,
		Instant createdAt) {
}
