package com.yuruicamp.backend.coupon.api;

import jakarta.validation.constraints.NotNull;

// 接收會員要領取的優惠券主檔 ID。
public record CouponClaimRequest(@NotNull Long couponId) {
}
