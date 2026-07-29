package com.yuruicamp.backend.coupon.domain;

// 對應會員領券後的生命週期狀態。
public enum CouponClaimStatus {
	claimed,
	consumed,
	revoked,
	expired
}
