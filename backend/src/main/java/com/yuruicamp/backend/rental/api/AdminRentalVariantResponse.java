package com.yuruicamp.backend.rental.api;

import java.time.Instant;

/**
 * 後台租借規格回應；不含庫存與售價（分別歸 G-3、W2-04）。
 * Admin rental SKU variant response (no stock, no price — out of scope here).
 */
public record AdminRentalVariantResponse(
		String id,
		String sku,
		String color,
		String size,
		String specification,
		String status,
		Instant createdAt,
		Instant updatedAt) {
}
