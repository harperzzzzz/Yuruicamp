package com.yuruicamp.backend.coupon.api;

// 回傳優惠券主檔與目前剩餘可領數量。
public record CouponResponse(
		Long id,
		String code,
		String name,
		String discountType,
		String discountValue,
		String minimumAmount,
		String category,
		String status,
		String validFrom,
		String validUntil,
		int issueQuantity,
		int claimedQuantity,
		int remainingClaimable) {
}
