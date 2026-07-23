package com.yuruicamp.backend.rental.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 後台租借規格（rental_sku_variants）輸入。
 * Admin rental SKU variant input.
 *
 * <p>既有規格請帶回 {@code id}；新規格留空，ID 由後端產生。
 * 這裡刻意沒有 price／onHand／stock 欄位——租借的售價在 W2-04 listing 那一層，
 * 庫存則永遠只能用 G-3 inventory movements 寫，本 API 完全不碰。</p>
 */
public record AdminRentalVariantRequest(
		@Size(max = 64) String id,
		@NotBlank @Size(max = 64) String sku,
		@Size(max = 100) String color,
		@Size(max = 100) String size,
		@NotBlank @Size(max = 200) String specification,
		@NotBlank @Pattern(regexp = "active|inactive") String status) {
}
