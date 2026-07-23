package com.yuruicamp.backend.catalog.api;

import java.time.Instant;

/**
 * 分類主檔回應（W2-01）。
 * Admin product category response.
 */
public record AdminCategoryResponse(
		long id,
		String code,
		String name,
		int sortOrder,
		Instant createdAt,
		Instant updatedAt) {
}
