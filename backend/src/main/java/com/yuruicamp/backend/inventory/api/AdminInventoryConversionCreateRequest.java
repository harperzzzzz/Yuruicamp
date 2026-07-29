package com.yuruicamp.backend.inventory.api;

import java.time.Instant;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * ADM-W2-05：建立「商城→租借」跨領域庫存轉換草稿。
 * 一次請求會在同一交易內建立兩張異動表頭（store conversion_out + rental conversion_in）
 * 與一筆 inventory_conversions 配對紀錄；此步驟不改動任何庫存數量。
 *
 * <p>Creates the draft pair for a store→rental inventory conversion in a single
 * transaction (store {@code conversion_out} movement + rental {@code conversion_in}
 * movement + one {@code inventory_conversions} row). Stock quantities are untouched
 * until {@code POST /{id}/post}.</p>
 */
public record AdminInventoryConversionCreateRequest(
		@NotBlank @Size(max = 32) String sourceLocationId,
		@NotBlank @Size(max = 32) String destinationLocationId,
		@NotBlank @Size(max = 64) String sourceVariantId,
		@NotBlank @Size(max = 64) String destinationRentalVariantId,
		@Min(1) @Max(1000000) int quantity,
		@NotBlank @Size(max = 1000) String reason,
		Instant occurredAt,
		@NotBlank @Size(max = 128) String idempotencyKey) {
}
