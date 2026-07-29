package com.yuruicamp.backend.customer.api;

/**
 * 後台偏好選項 lookup 回應（W1-05；本季不做主檔 CRUD）。
 * Admin preference-option lookup row (read-only this season).
 */
public record AdminPreferenceOptionResponse(
		long id,
		String type,
		String code,
		String label,
		int sortOrder,
		boolean active) {
}
