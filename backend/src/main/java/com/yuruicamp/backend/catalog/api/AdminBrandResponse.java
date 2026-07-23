package com.yuruicamp.backend.catalog.api;

import java.time.Instant;

/**
 * 品牌主檔回應（W2-02）。
 * Admin brand response.
 */
public record AdminBrandResponse(
		String id,
		String name,
		String logoUrl,
		int sortOrder,
		Instant createdAt,
		Instant updatedAt) {
}
