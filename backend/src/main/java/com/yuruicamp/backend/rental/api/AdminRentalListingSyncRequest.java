package com.yuruicamp.backend.rental.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

/**
 * 後台租借上架同步（sync）輸入：本次 request 代表「這個租借 SKU 底下，
 * 所有營區上架資料現在應該長怎樣」的完整清單。
 * Admin rental listing sync input: full desired state for one rental SKU.
 *
 * <p>語意固定為<b>整組取代</b>（跟會員標籤指派 {@code PUT .../tags} 一樣）：</p>
 * <ul>
 *   <li>body 出現的 {@code (campgroundId, rentalSkuVariantId)} → 新增或更新該筆 listing</li>
 *   <li>DB 已存在但這次沒出現的組合 → 改成 {@code active=false}（<b>軟停用，不硬刪</b>，
 *       因為 {@code booking_selected_rentals} 對 listing 有 {@code ON DELETE RESTRICT}，
 *       曾經被訂過的 listing 本來就刪不掉）</li>
 *   <li>{@code listings: []} → 這個 SKU 底下全部 campground 上架都下架</li>
 * </ul>
 */
public record AdminRentalListingSyncRequest(
		@NotNull List<@Valid AdminRentalListingRequest> listings) {
}
