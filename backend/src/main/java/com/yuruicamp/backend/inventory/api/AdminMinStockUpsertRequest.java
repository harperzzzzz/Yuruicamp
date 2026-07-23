package com.yuruicamp.backend.inventory.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

/**
 * 批次 upsert 最低庫存閾值（不改 on_hand）。
 * Bulk upsert min-stock thresholds (does not change on_hand).
 */
public record AdminMinStockUpsertRequest(
		@NotBlank @Size(max = 16) String inventoryDomain,
		@NotEmpty @Valid List<AdminMinStockItemRequest> items) {
}
