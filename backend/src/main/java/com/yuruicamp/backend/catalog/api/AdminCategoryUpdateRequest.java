package com.yuruicamp.backend.catalog.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

/**
 * 更新分類主檔（有傳欄位才改）。
 * Patch product category.
 */
public record AdminCategoryUpdateRequest(
		@Size(max = 64) String code,
		@Size(max = 100) String name,
		@Min(0) Integer sortOrder) {
}
