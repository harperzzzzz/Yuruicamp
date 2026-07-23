package com.yuruicamp.backend.inventory.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 單筆最低庫存 upsert 項目。
 * One upsert item for min-stock bulk write.
 */
public record AdminMinStockItemRequest(
		@NotBlank @Size(max = 64) String variantId,
		@NotBlank @Size(max = 32) String locationId,
		@NotNull @Min(0) Integer minimumQuantity) {
}
