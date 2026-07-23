package com.yuruicamp.backend.customer.api;

import java.time.Instant;

/**
 * 後台會員標籤池主檔回應（含啟停與排序；與會員詳情內嵌的精簡 Tag 分開）。
 * Admin customer-tag pool response (full fields; separate from embedded customer tags).
 */
public record AdminCustomerTagPoolResponse(
		long id,
		String name,
		String color,
		int sortOrder,
		boolean active,
		Instant createdAt,
		Instant updatedAt) {
}
