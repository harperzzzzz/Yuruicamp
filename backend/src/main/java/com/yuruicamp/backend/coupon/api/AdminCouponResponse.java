package com.yuruicamp.backend.coupon.api;

import java.time.Instant;

/**
 * 後台優惠券主檔、領取量與維護時間的完整回應。
 */
public record AdminCouponResponse(
		long id,
		String code,
		String name,
		String discountType,
		String discountValue,
		String minimumAmount,
		int issueQuantity,
		int claimedQuantity,
		int remainingClaimable,
		Instant validFrom,
		Instant validUntil,
		String status,
		String category,
		Instant createdAt,
		Instant updatedAt) {
}
