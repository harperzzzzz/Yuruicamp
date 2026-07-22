package com.yuruicamp.backend.inventory.api;

import java.time.Instant;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 建立庫存異動草稿的表頭資料，操作者與單號由後端決定。
 */
public record AdminInventoryMovementCreateRequest(
		@NotBlank @Pattern(regexp = "store|rental") String inventoryDomain,
		@NotBlank @Pattern(regexp = "receipt|write_off|transfer") String movementType,
		@Size(max = 32) String sourceLocationId,
		@Size(max = 32) String destinationLocationId,
		@NotBlank @Size(max = 1000) String reason,
		Instant occurredAt) {
}
