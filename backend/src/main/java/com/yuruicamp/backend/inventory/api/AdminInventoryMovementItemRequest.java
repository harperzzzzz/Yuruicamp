package com.yuruicamp.backend.inventory.api;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 草稿異動單的單筆商品規格與正整數數量。
 */
public record AdminInventoryMovementItemRequest(
		@NotBlank @Size(max = 64) String variantId,
		@Min(1) @Max(1000000) int quantity) {
}
