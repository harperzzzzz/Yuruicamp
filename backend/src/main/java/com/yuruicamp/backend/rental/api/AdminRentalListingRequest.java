package com.yuruicamp.backend.rental.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 後台租借上架（{@code rental_listings}）單筆輸入（W2-04）。
 * Admin rental listing single-item input.
 *
 * <p>自然鍵是 {@code (campgroundId, rentalSkuVariantId)}——DB 本身有
 * {@code UNIQUE (campground_id, rental_sku_variant_id)}，同一營區同一規格永遠只會有
 * 一筆 listing，所以這裡故意<b>不接受 {@code id}</b>：後端用這兩個欄位當 upsert key，
 * 不需要前端先查 id 再回填，也不會因為忘記帶 id 而重複建立。</p>
 *
 * <p>價格與折扣的範圍對齊 DB CHECK
 * {@code ck_rental_listings_prices}：兩個日租價都必須 ≥ 0，折扣只能在
 * 0.00～0.30（最多 30%）之間。</p>
 */
public record AdminRentalListingRequest(
		@NotBlank @Size(max = 32) String campgroundId,
		@NotBlank @Size(max = 64) String rentalSkuVariantId,
		@NotNull @DecimalMin("0.00") BigDecimal pricePerDayWeekday,
		@NotNull @DecimalMin("0.00") BigDecimal pricePerDayHoliday,
		@DecimalMin("0.00") @DecimalMax("0.30") BigDecimal discount,
		@Size(max = 100) String terrain,
		@Size(max = 20000) String description,
		@NotNull Boolean active) {
}
