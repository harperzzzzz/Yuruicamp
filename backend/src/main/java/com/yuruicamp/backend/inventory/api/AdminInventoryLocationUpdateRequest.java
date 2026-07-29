package com.yuruicamp.backend.inventory.api;

import jakarta.validation.constraints.Size;

/**
 * 更新庫位（可改 name／active；其餘欄位建立後不可改）。
 * Patch inventory location (name / active only).
 */
public record AdminInventoryLocationUpdateRequest(
		@Size(max = 120) String name,
		Boolean active) {
}
