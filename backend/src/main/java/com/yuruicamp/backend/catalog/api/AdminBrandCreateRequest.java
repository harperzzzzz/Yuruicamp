package com.yuruicamp.backend.catalog.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 建立品牌主檔（客戶端提供 slug id）。
 * Create brand with client-provided slug id.
 */
public record AdminBrandCreateRequest(
		@NotBlank @Size(max = 32) String id,
		@NotBlank @Size(max = 120) String name,
		String logoUrl,
		@Min(0) Integer sortOrder) {
}
