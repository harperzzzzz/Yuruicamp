package com.yuruicamp.backend.rental.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 後台建立／更新租借 SKU 輸入。
 * Admin rental SKU create／update input.
 *
 * <p><b>建立策略（已定案）</b>：本 API 建立時一律「新建」一筆 {@code equipment_items}，
 * 不支援帶入既有 {@code itemId} 重用。若之後要讓同一裝備同時可賣可租，
 * 屬另一張票（W2-04 之後），本 Request 現在故意不接受 {@code itemId}。</p>
 *
 * <p>不接受 {@code onHand}／{@code totalStock}／任何庫存或 rental_listings 定價欄位——
 * 這裡的 DTO 根本沒有宣告這些欄位，就算前端多送，Jackson 預設也只會忽略它，
 * 後端邏輯完全不會讀到、更不會拿去寫 {@code rental_sku_variant_stocks}。</p>
 */
public record AdminRentalUpsertRequest(
		@NotBlank @Size(max = 200) String name,
		@Size(max = 20000) String description,
		@NotNull Long categoryId,
		@Size(max = 32) String brandId,
		@NotBlank @Pattern(regexp = "active|inactive") String status,
		@NotEmpty @Size(max = 100) List<@Valid AdminRentalVariantRequest> variants) {
}
