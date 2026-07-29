package com.yuruicamp.backend.catalog.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 建立分類主檔。
 * Create product category.
 */
public record AdminCategoryCreateRequest(
		@NotBlank @Size(max = 64) String code,
		@NotBlank @Size(max = 100) String name,
		@Min(0) Integer sortOrder) {
}
