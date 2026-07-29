package com.yuruicamp.backend.coupon.api;

// 回傳會員領券狀態與對應的優惠券摘要。
public record CouponClaimResponse(
		Long id,
		Long couponId,
		String status,
		String claimedAt,
		String consumedAt,
		CouponResponse coupon) {
}
