package com.yuruicamp.backend.rental.api;

import java.time.Instant;

/**
 * 後台租借上架回應：{@code rental_listings} 加上營區名稱與規格 SKU／規格說明，
 * 方便前端表格直接顯示，不用再多打一次查詢。
 * Admin rental listing response, enriched with campground name and variant SKU.
 *
 * <p>金額欄位固定用 {@code String}（已四捨五入到小數兩位），跟整個專案的金額慣例
 * 一致（例如 {@code AdminProductVariantResponse.price}／公開契約的
 * {@code RentalEquipmentResponse.pricePerDayWeekday}），避免 JSON number
 * 被前端當成 binary float 處理，出現 180.00 顯示成 180.0 的問題。</p>
 */
public record AdminRentalListingResponse(
		String id,
		String campgroundId,
		String campgroundName,
		String rentalSkuVariantId,
		String sku,
		String specification,
		String pricePerDayWeekday,
		String pricePerDayHoliday,
		String discount,
		String terrain,
		String description,
		boolean active,
		Instant createdAt,
		Instant updatedAt) {
}
