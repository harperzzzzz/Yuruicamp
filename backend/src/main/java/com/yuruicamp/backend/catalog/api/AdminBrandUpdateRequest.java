package com.yuruicamp.backend.catalog.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

/**
 * 更新品牌主檔（不可改 id）。
 * Patch brand (id immutable).
 */
public record AdminBrandUpdateRequest(
		@Size(max = 120) String name,
		String logoUrl,
		@Min(0) Integer sortOrder) {
}
